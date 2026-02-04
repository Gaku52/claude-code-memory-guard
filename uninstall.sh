#!/bin/bash
# claude-code-memory-guard uninstaller
# Usage: bash uninstall.sh

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${HOME}/CLAUDE.md"

echo "=== claude-code-memory-guard uninstaller ==="
echo ""

# --- 1. Remove script ---
if [[ -f "$CLAUDE_DIR/memory-guard.sh" ]]; then
  rm "$CLAUDE_DIR/memory-guard.sh"
  echo "[1/5] Removed memory-guard.sh"
else
  echo "[1/5] memory-guard.sh not found, skipping"
fi

# --- 2. Remove config ---
if [[ -f "$CLAUDE_DIR/memory-guard-config.env" ]]; then
  rm "$CLAUDE_DIR/memory-guard-config.env"
  echo "[2/5] Removed config file"
else
  echo "[2/5] Config file not found, skipping"
fi

# --- 3. Remove counter file ---
if [[ -f "$CLAUDE_DIR/memory-guard-counter" ]]; then
  rm "$CLAUDE_DIR/memory-guard-counter"
  echo "[3/5] Removed counter file"
else
  echo "[3/5] Counter file not found, skipping"
fi

# --- 4. Remove hook from settings.json ---
if [[ -f "$SETTINGS_FILE" ]]; then
  if command -v jq &>/dev/null; then
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
      echo "[4/5] Removed hook from settings.json"
    else
      echo "[4/5] No PostToolUse hooks found, skipping"
    fi
  else
    echo "[4/5] WARNING: jq not found. Please manually remove the memory-guard hook from $SETTINGS_FILE"
  fi
else
  echo "[4/5] settings.json not found, skipping"
fi

# --- 5. Remove rules from CLAUDE.md ---
MARKER_START="# Memory Management Rules (claude-code-memory-guard)"
MARKER_END="- Avoid accumulating large amounts of file content in conversation context"

if [[ -f "$CLAUDE_MD" ]]; then
  if grep -qF "$MARKER_START" "$CLAUDE_MD"; then
    # Remove the memory guard section (from marker to end of block)
    # Use sed to delete from start marker to end marker (inclusive)
    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$CLAUDE_MD"
    # Clean up any trailing blank lines left behind
    sed -i.bak -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CLAUDE_MD"
    rm -f "${CLAUDE_MD}.bak"
    echo "[5/5] Removed memory rules from CLAUDE.md"
  else
    echo "[5/5] Memory rules not found in CLAUDE.md, skipping"
  fi
else
  echo "[5/5] CLAUDE.md not found, skipping"
fi

# --- Remove log files ---
if [[ -f "$CLAUDE_DIR/memory-guard.log" ]]; then
  rm -f "$CLAUDE_DIR/memory-guard.log" "$CLAUDE_DIR/memory-guard.log.old"
  echo ""
  echo "Removed log files"
fi

echo ""
echo "=== Uninstallation complete ==="
echo "Memory guard has been fully removed."
