#!/bin/bash
# claude-code-memory-guard installer
# Usage: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${HOME}/CLAUDE.md"

echo "=== claude-code-memory-guard installer ==="
echo ""

# --- 1. Ensure ~/.claude/ exists ---
mkdir -p "$CLAUDE_DIR"
echo "[1/5] ~/.claude/ directory ready"

# --- 2. Copy memory-guard.sh ---
cp "$SCRIPT_DIR/memory-guard.sh" "$CLAUDE_DIR/memory-guard.sh"
chmod +x "$CLAUDE_DIR/memory-guard.sh"
echo "[2/5] memory-guard.sh installed to ~/.claude/"

# --- 3. Copy config ---
if [[ ! -f "$CLAUDE_DIR/memory-guard-config.env" ]]; then
  cp "$SCRIPT_DIR/config.env" "$CLAUDE_DIR/memory-guard-config.env"
  echo "[3/5] Default config installed to ~/.claude/memory-guard-config.env"
else
  echo "[3/5] Config already exists, skipping (edit ~/.claude/memory-guard-config.env to customize)"
fi

# --- 4. Merge hooks into settings.json ---
HOOK_ENTRY='{"type":"command","command":"bash ~/.claude/memory-guard.sh","timeout":10000}'

if [[ -f "$SETTINGS_FILE" ]]; then
  # Check if jq is available
  if command -v jq &>/dev/null; then
    # Check if hook already exists
    if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command == "bash ~/.claude/memory-guard.sh")' "$SETTINGS_FILE" &>/dev/null; then
      echo "[4/5] Hook already registered in settings.json, skipping"
    else
      # Merge hook into existing settings
      jq --argjson hook "$HOOK_ENTRY" '
        .hooks //= {} |
        .hooks.PostToolUse //= [] |
        .hooks.PostToolUse += [{"matcher": "", "hooks": [$hook]}]
      ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      echo "[4/5] Hook added to settings.json"
    fi
  else
    echo "[4/5] WARNING: jq not found. Please manually add the hook to $SETTINGS_FILE"
    echo "       Install jq with: brew install jq"
    echo "       Or manually copy from: $SCRIPT_DIR/hooks-config.json"
  fi
else
  # Create new settings.json
  if command -v jq &>/dev/null; then
    jq -n --argjson hook "$HOOK_ENTRY" '{
      "hooks": {
        "PostToolUse": [{"matcher": "", "hooks": [$hook]}]
      }
    }' > "$SETTINGS_FILE"
    echo "[4/5] Created settings.json with hook"
  else
    cp "$SCRIPT_DIR/hooks-config.json" "$SETTINGS_FILE"
    echo "[4/5] Created settings.json from template (install jq for safer merging)"
  fi
fi

# --- 5. Append rules to CLAUDE.md ---
MARKER="# Memory Management Rules (claude-code-memory-guard)"

if [[ -f "$CLAUDE_MD" ]]; then
  if grep -qF "$MARKER" "$CLAUDE_MD"; then
    echo "[5/5] Memory rules already in CLAUDE.md, skipping"
  else
    echo "" >> "$CLAUDE_MD"
    cat "$SCRIPT_DIR/claude-md-snippet.md" >> "$CLAUDE_MD"
    echo "[5/5] Memory rules appended to CLAUDE.md"
  fi
else
  cp "$SCRIPT_DIR/claude-md-snippet.md" "$CLAUDE_MD"
  echo "[5/5] Created CLAUDE.md with memory rules"
fi

# --- Verification ---
echo ""
echo "=== Installation complete ==="
echo ""
echo "Verifying installation:"

errors=0

if [[ -x "$CLAUDE_DIR/memory-guard.sh" ]]; then
  echo "  ✓ memory-guard.sh is executable"
else
  echo "  ✗ memory-guard.sh not found or not executable"
  errors=$((errors + 1))
fi

if [[ -f "$CLAUDE_DIR/memory-guard-config.env" ]]; then
  echo "  ✓ Config file exists"
else
  echo "  ✗ Config file missing"
  errors=$((errors + 1))
fi

if [[ -f "$SETTINGS_FILE" ]] && grep -q "memory-guard" "$SETTINGS_FILE"; then
  echo "  ✓ Hook registered in settings.json"
else
  echo "  ✗ Hook not found in settings.json"
  errors=$((errors + 1))
fi

if [[ -f "$CLAUDE_MD" ]] && grep -qF "$MARKER" "$CLAUDE_MD"; then
  echo "  ✓ Memory rules in CLAUDE.md"
else
  echo "  ✗ Memory rules not found in CLAUDE.md"
  errors=$((errors + 1))
fi

echo ""
if [[ $errors -eq 0 ]]; then
  echo "All checks passed! Memory guard is active."
  echo ""
  echo "Customize thresholds: edit ~/.claude/memory-guard-config.env"
  echo "View logs: cat ~/.claude/memory-guard.log"
  echo "Disable: set MEMORY_GUARD_ENABLED=false in config"
else
  echo "WARNING: $errors check(s) failed. Review the output above."
fi
