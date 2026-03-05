#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const nowIso = () => new Date().toISOString();
const runId = process.env.WS_RELEASE_RUN_ID || `release-${Date.now()}`;
const telemetryDir = path.join(repoRoot, "dist", "telemetry");
const telemetryPath = path.join(telemetryDir, "ecosystem-release.ndjson");
const observabilityPath = path.join(repoRoot, "dist", "ecosystem-observability.json");

function writeTelemetry(event) {
  fs.mkdirSync(telemetryDir, { recursive: true });
  fs.appendFileSync(telemetryPath, JSON.stringify(event) + "\n", "utf8");
}

function runStep(stepId, cmd, args) {
  const startedAt = Date.now();
  const startedIso = nowIso();
  console.log(`[ecosystem:release] ${stepId}: ${cmd} ${args.join(" ")}`);
  writeTelemetry({
    ts: startedIso,
    runId,
    event: "step_start",
    stepId,
    cmd,
    args,
  });

  const result = spawnSync(cmd, args, {
    cwd: repoRoot,
    stdio: "inherit",
    env: process.env,
  });

  const endedAt = Date.now();
  const durationMs = endedAt - startedAt;
  const status = typeof result.status === "number" ? result.status : 1;
  const ok = status === 0;
  writeTelemetry({
    ts: nowIso(),
    runId,
    event: "step_end",
    stepId,
    ok,
    status,
    durationMs,
  });

  return {
    stepId,
    ok,
    status,
    durationMs,
    startedAt: startedIso,
    endedAt: nowIso(),
  };
}

function writeObservabilityReport(report) {
  fs.mkdirSync(path.dirname(observabilityPath), { recursive: true });
  fs.writeFileSync(observabilityPath, JSON.stringify(report, null, 2) + "\n", "utf8");
}

const steps = [
  { id: "rules_publish", cmd: "npm", args: ["run", "rules:publish"] },
  { id: "ecosystem_smoke", cmd: "npm", args: ["run", "ecosystem:smoke"] },
  { id: "compat_check", cmd: "npm", args: ["run", "compat:check"] },
  { id: "sdk_readiness", cmd: "npm", args: ["run", "sdk:readiness"] },
  { id: "platform_readiness", cmd: "npm", args: ["run", "platform:readiness"] },
  { id: "release_summary", cmd: "node", args: ["scripts/write-release-summary.mjs"] },
];

const runStarted = Date.now();
writeTelemetry({
  ts: nowIso(),
  runId,
  event: "run_start",
  workflow: "ecosystem:release",
});

const stepResults = [];
let failedStep = null;
for (const step of steps) {
  const result = runStep(step.id, step.cmd, step.args);
  stepResults.push(result);
  if (!result.ok) {
    failedStep = result;
    break;
  }
}

const totalDurationMs = Date.now() - runStarted;
const report = {
  generatedAt: nowIso(),
  runId,
  workflow: "ecosystem:release",
  ok: failedStep === null,
  totalDurationMs,
  failedStepId: failedStep?.stepId ?? null,
  steps: stepResults,
  alerts: [],
};

if (failedStep) {
  report.alerts.push({
    severity: "critical",
    type: "release_step_failed",
    message: `Step ${failedStep.stepId} failed with status ${failedStep.status}`,
  });
}

writeObservabilityReport(report);
writeTelemetry({
  ts: nowIso(),
  runId,
  event: "run_end",
  ok: report.ok,
  totalDurationMs,
  failedStepId: report.failedStepId,
});

if (failedStep) {
  console.error(
    `[ecosystem:release] FAILED at ${failedStep.stepId}; observability report: ${observabilityPath}`
  );
  process.exit(failedStep.status || 1);
}

console.log(
  `[ecosystem:release] Completed successfully in ${totalDurationMs}ms; observability report: ${observabilityPath}`
);
