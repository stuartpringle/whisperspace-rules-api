#!/usr/bin/env bash
set -euo pipefail

echo "[ecosystem:release] Starting release orchestration..."
echo "[ecosystem:release] Step 1/4: publish rules-api payloads"
npm run rules:publish

echo "[ecosystem:release] Step 2/4: run downstream ecosystem smoke checks"
npm run ecosystem:smoke

echo "[ecosystem:release] Step 3/4: re-validate compatibility matrix/manifests"
npm run compat:check

echo "[ecosystem:release] Step 4/4: write release summary artifact"
node scripts/write-release-summary.mjs

echo "[ecosystem:release] Completed successfully."
