#!/bin/bash
# claude-code-memory-guard installer (macOS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${HOME}/CLAUDE.md"

echo "=== claude-code-memory-guard installer (macOS) ==="
echo ""

# 1. Ensure ~/.claude/
mkdir -p "$CLAUDE_DIR"
echo "[1/5] ~/.claude/ directory ready"

# 2. Copy script
cp "$SCRIPT_DIR/memory-guard.sh" "$CLAUDE_DIR/memory-guard.sh"
chmod +x "$CLAUDE_DIR/memory-guard.sh"
echo "[2/5] memory-guard.sh installed"

# 3. Copy config
if [[ ! -f "$CLAUDE_DIR/memory-guard-config.env" ]]; then
  cp "$REPO_DIR/config.env" "$CLAUDE_DIR/memory-guard-config.env"
  echo "[3/5] Default config installed"
else
  echo "[3/5] Config already exists, skipping"
fi

# 4. Merge hook into settings.json
HOOK_ENTRY='{"type":"command","command":"bash ~/.claude/memory-guard.sh","timeout":10000}'

if [[ -f "$SETTINGS_FILE" ]]; then
  if command -v jq &>/dev/null; then
    if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command == "bash ~/.claude/memory-guard.sh")' "$SETTINGS_FILE" &>/dev/null; then
      echo "[4/5] Hook already registered, skipping"
    else
      jq --argjson hook "$HOOK_ENTRY" '
        .hooks //= {} |
        .hooks.PostToolUse //= [] |
        .hooks.PostToolUse += [{"matcher": "", "hooks": [$hook]}]
      ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      echo "[4/5] Hook added to settings.json"
    fi
  else
    echo "[4/5] WARNING: jq not found (brew install jq). Manually add hook from hooks-config.json"
  fi
else
  if command -v jq &>/dev/null; then
    jq -n --argjson hook "$HOOK_ENTRY" '{
      "hooks": {"PostToolUse": [{"matcher": "", "hooks": [$hook]}]}
    }' > "$SETTINGS_FILE"
    echo "[4/5] Created settings.json with hook"
  else
    echo "[4/5] WARNING: jq not found. Manually create settings.json"
  fi
fi

# 5. Append CLAUDE.md rules
MARKER="# Memory Management Rules (claude-code-memory-guard)"
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -qF "$MARKER" "$CLAUDE_MD"; then
    echo "[5/5] Memory rules already in CLAUDE.md, skipping"
  else
    echo "" >> "$CLAUDE_MD"
    cat "$REPO_DIR/claude-md-snippet.md" >> "$CLAUDE_MD"
    echo "[5/5] Memory rules appended to CLAUDE.md"
  fi
else
  cp "$REPO_DIR/claude-md-snippet.md" "$CLAUDE_MD"
  echo "[5/5] Created CLAUDE.md with memory rules"
fi

# Verification
echo ""
echo "=== Verifying ==="
errors=0
[[ -x "$CLAUDE_DIR/memory-guard.sh" ]] && echo "  ✓ Script executable" || { echo "  ✗ Script missing"; errors=$((errors+1)); }
[[ -f "$CLAUDE_DIR/memory-guard-config.env" ]] && echo "  ✓ Config exists" || { echo "  ✗ Config missing"; errors=$((errors+1)); }
[[ -f "$SETTINGS_FILE" ]] && grep -q "memory-guard" "$SETTINGS_FILE" && echo "  ✓ Hook registered" || { echo "  ✗ Hook missing"; errors=$((errors+1)); }
[[ -f "$CLAUDE_MD" ]] && grep -qF "$MARKER" "$CLAUDE_MD" && echo "  ✓ CLAUDE.md rules" || { echo "  ✗ CLAUDE.md rules missing"; errors=$((errors+1)); }

echo ""
if [[ $errors -eq 0 ]]; then
  echo "All checks passed. Memory guard is active."
else
  echo "WARNING: $errors check(s) failed."
fi
