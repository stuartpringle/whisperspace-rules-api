#!/usr/bin/env bash
set -euo pipefail

REQUIRED_MCPS=(
  "playwright"
)

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not found in PATH."
  exit 1
fi

missing=()
for mcp in "${REQUIRED_MCPS[@]}"; do
  if ! codex mcp get "$mcp" >/dev/null 2>&1; then
    missing+=("$mcp")
  fi
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "MCP check passed. Installed: ${REQUIRED_MCPS[*]}"
  exit 0
fi

echo "Missing required MCP server(s): ${missing[*]}"
echo
echo "Install commands:"
for mcp in "${missing[@]}"; do
  case "$mcp" in
    playwright)
      echo "  codex mcp add playwright -- npx -y @playwright/mcp@latest"
      ;;
    *)
      echo "  codex mcp add ${mcp} -- <command>"
      ;;
  esac
done
echo
echo "Verify with:"
echo "  codex mcp list"
echo "  codex mcp get playwright --json"
exit 2
