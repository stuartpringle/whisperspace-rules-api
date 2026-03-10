#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const sdkReadinessPath = path.join(repoRoot, "compatibility", "sdk-readiness.json");
const platformReadinessPath = path.join(repoRoot, "compatibility", "platform-client-readiness.json");
const outputPath = path.join(repoRoot, "compatibility", "eco-readiness-report.json");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function listFilesRecursive(rootDir) {
  const out = [];
  const stack = [rootDir];
  while (stack.length > 0) {
    const current = stack.pop();
    if (!current || !fs.existsSync(current)) continue;
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === ".git" || entry.name === "node_modules" || entry.name === "dist") {
        continue;
      }
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (entry.isFile()) {
        out.push(fullPath);
      }
    }
  }
  return out;
}

function scanForMarkers(repoPath, roots, markers) {
  const findings = [];
  const normalizedMarkers = markers.map((m) => String(m).toLowerCase()).filter(Boolean);
  for (const relRoot of roots) {
    const scanRoot = path.join(repoPath, relRoot);
    if (!fs.existsSync(scanRoot)) continue;
    for (const filePath of listFilesRecursive(scanRoot)) {
      if (!/\.(ts|tsx|js|mjs|json|md|sh|php)$/i.test(filePath)) continue;
      let content = "";
      try {
        content = fs.readFileSync(filePath, "utf8");
      } catch {
        continue;
      }
      const lower = content.toLowerCase();
      for (const marker of normalizedMarkers) {
        if (lower.includes(marker)) {
          findings.push({
            marker,
            file: filePath,
          });
        }
      }
    }
  }
  return findings;
}

function scanPlatformClientUsage(repoPath) {
  const files = listFilesRecursive(path.join(repoPath, "src"));
  let createPlatformClientRefs = 0;
  let platformClientImportRefs = 0;
  const examples = [];

  for (const filePath of files) {
    if (!/\.(ts|tsx|js|mjs)$/i.test(filePath)) continue;
    let content = "";
    try {
      content = fs.readFileSync(filePath, "utf8");
    } catch {
      continue;
    }

    const createCount = (content.match(/createPlatformClient\s*\(/g) ?? []).length;
    const importCount = (content.match(/@whisperspace\/sdk(?:\/platform-client)?/g) ?? []).length;
    createPlatformClientRefs += createCount;
    platformClientImportRefs += importCount;
    if ((createCount > 0 || importCount > 0) && examples.length < 8) {
      examples.push(filePath);
    }
  }

  return { createPlatformClientRefs, platformClientImportRefs, examples };
}

if (!fs.existsSync(sdkReadinessPath) || !fs.existsSync(platformReadinessPath)) {
  console.error("eco:readiness:scan ERROR: missing compatibility readiness files.");
  process.exit(1);
}

const sdkReadiness = readJson(sdkReadinessPath);
const platformReadiness = readJson(platformReadinessPath);

const sdkRepos = Array.isArray(sdkReadiness.repos) ? sdkReadiness.repos : [];
const platformRepos = Array.isArray(platformReadiness.repos) ? platformReadiness.repos : [];

const report = {
  generatedAt: new Date().toISOString(),
  sdkTargetSchema: sdkReadiness.targetCharacterRecordSchema ?? null,
  platformTargetPackage: platformReadiness.targetPackage ?? null,
  sdk: [],
  platform: [],
};

for (const repoEntry of sdkRepos) {
  const repoPath = String(repoEntry.repoPath ?? "").trim();
  const scanRoots = Array.isArray(repoEntry.scanRoots) && repoEntry.scanRoots.length > 0
    ? repoEntry.scanRoots
    : ["src"];
  const forbiddenMarkers = Array.isArray(repoEntry.forbiddenMarkers) && repoEntry.forbiddenMarkers.length > 0
    ? repoEntry.forbiddenMarkers
    : ["compatibility shim", "local shim", "sdk compatibility adapter"];
  const exists = repoPath && fs.existsSync(repoPath);
  const findings = exists ? scanForMarkers(repoPath, scanRoots, forbiddenMarkers) : [];

  report.sdk.push({
    repo: repoEntry.repo,
    status: repoEntry.status ?? "unknown",
    shimFree: repoEntry.shimFree ?? null,
    repoPath,
    exists,
    markerHits: findings.length,
    findings: findings.slice(0, 25),
  });
}

for (const repoEntry of platformRepos) {
  const repoName = String(repoEntry.repo ?? "");
  const sdkEntry = sdkRepos.find((x) => x?.repo === repoName);
  const repoPath = String(sdkEntry?.repoPath ?? "").trim();
  const exists = repoPath && fs.existsSync(repoPath);
  const usage = exists ? scanPlatformClientUsage(repoPath) : { createPlatformClientRefs: 0, platformClientImportRefs: 0, examples: [] };

  report.platform.push({
    repo: repoName,
    status: repoEntry.status ?? "unknown",
    adopted: repoEntry.adopted ?? null,
    repoPath,
    exists,
    ...usage,
  });
}

fs.writeFileSync(outputPath, JSON.stringify(report, null, 2) + "\n", "utf8");
console.log(`eco:readiness:scan wrote ${outputPath}`);
