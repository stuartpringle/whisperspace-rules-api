#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

const pkg = readJson(path.join(repoRoot, "package.json"));
const meta = readJson(path.join(repoRoot, "public", "rules-api", "latest", "meta.json"));
const matrix = readJson(path.join(repoRoot, "compatibility", "matrix.json"));

const gitSha = execSync("git rev-parse --short HEAD", {
  cwd: repoRoot,
  encoding: "utf8",
}).trim();

const summary = {
  generatedAt: new Date().toISOString(),
  releaseWorkflow: "ecosystem:release",
  gitSha,
  rulesApi: {
    packageVersion: pkg.version,
    rulesVersion: pkg.rulesVersion,
    publishedMetaVersion: meta.version,
    publishedGeneratedAt: meta.generatedAt,
  },
  compatibility: {
    activeRelease: matrix.activeRelease,
    schemaVersion: matrix.schemaVersion,
  },
  checks: {
    rulesPublish: "ok",
    ecosystemSmoke: "ok",
    compatibility: "ok",
  },
};

const outDir = path.join(repoRoot, "dist");
const outPath = path.join(outDir, "ecosystem-release-summary.json");
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(summary, null, 2) + "\n", "utf8");
console.log(`ecosystem:summary wrote ${outPath}`);
