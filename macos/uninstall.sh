#!/bin/bash
# claude-code-memory-guard uninstaller (macOS)

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${HOME}/CLAUDE.md"

echo "=== claude-code-memory-guard uninstaller (macOS) ==="
echo ""

# 1. Remove script
rm -f "$CLAUDE_DIR/memory-guard.sh"
echo "[1/5] Removed memory-guard.sh"

# 2. Remove config
rm -f "$CLAUDE_DIR/memory-guard-config.env"
echo "[2/5] Removed config"

# 3. Remove counter
rm -f "$CLAUDE_DIR/memory-guard-counter"
echo "[3/5] Removed counter"

# 4. Remove hook from settings.json
if [[ -f "$SETTINGS_FILE" ]] && command -v jq &>/dev/null; then
  if jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" &>/dev/null; then
    jq '
      .hooks.PostToolUse = [
        .hooks.PostToolUse[] |
        .hooks = [.hooks[] | select(.command != "bash ~/.claude/memory-guard.sh")] |
        select(.hooks | length > 0)
      ] |
      if .hooks.PostToolUse | length == 0 then del(.hooks.PostToolUse) else . end |
      if .hooks | length == 0 then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  fi
  echo "[4/5] Removed hook from settings.json"
else
  echo "[4/5] Skipped (no settings.json or jq)"
fi

# 5. Remove CLAUDE.md rules
MARKER_START="# Memory Management Rules (claude-code-memory-guard)"
MARKER_END="- Avoid accumulating large amounts of file content in conversation context"
if [[ -f "$CLAUDE_MD" ]] && grep -qF "$MARKER_START" "$CLAUDE_MD"; then
  sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$CLAUDE_MD"
  rm -f "${CLAUDE_MD}.bak"
  echo "[5/5] Removed CLAUDE.md rules"
else
  echo "[5/5] No rules found in CLAUDE.md"
fi

# Cleanup logs
rm -f "$CLAUDE_DIR/memory-guard.log" "$CLAUDE_DIR/memory-guard.log.old"
echo ""
echo "=== Uninstallation complete ==="
