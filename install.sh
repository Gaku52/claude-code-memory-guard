#!/bin/bash
# Claude Code Memory Guard - Installer
# https://github.com/Gaku52/claude-code-memory-guard

set -e

echo "========================================="
echo "Claude Code Memory Guard - Installer"
echo "========================================="
echo ""

# Check if Claude Code is installed
CLAUDE_DIR="${HOME}/.claude"
if [[ ! -d "$CLAUDE_DIR" ]]; then
  echo "❌ Error: Claude Code directory not found at ~/.claude"
  echo "Please install Claude Code first: https://claude.com/claude-code"
  exit 1
fi

echo "✅ Claude Code directory found"
echo ""

# Backup existing files
echo "📦 Backing up existing files..."
BACKUP_DIR="${CLAUDE_DIR}/memory-guard-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [[ -f "${CLAUDE_DIR}/memory-guard.sh" ]]; then
  cp "${CLAUDE_DIR}/memory-guard.sh" "$BACKUP_DIR/"
  echo "  - Backed up memory-guard.sh"
fi

if [[ -f "${CLAUDE_DIR}/settings.json" ]]; then
  cp "${CLAUDE_DIR}/settings.json" "$BACKUP_DIR/"
  echo "  - Backed up settings.json"
fi

echo ""

# Install memory-guard.sh
echo "📥 Installing memory-guard.sh..."
cp scripts/memory-guard.sh "${CLAUDE_DIR}/"
chmod +x "${CLAUDE_DIR}/memory-guard.sh"
echo "  - Installed to ~/.claude/memory-guard.sh"
echo ""

# Install commands
echo "📥 Installing slash commands..."
mkdir -p "${CLAUDE_DIR}/commands"
cp commands/memorystatus.md "${CLAUDE_DIR}/commands/"
echo "  - Installed /memorystatus command"
echo ""

# Install CLAUDE.md
echo "📥 Installing CLAUDE.md..."
if [[ -f "${HOME}/CLAUDE.md" ]]; then
  echo "  ⚠️  CLAUDE.md already exists in home directory"
  read -p "  Overwrite? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cp CLAUDE.md "${HOME}/"
    echo "  - Overwritten ~/CLAUDE.md"
  else
    echo "  - Skipped CLAUDE.md installation"
  fi
else
  cp CLAUDE.md "${HOME}/"
  echo "  - Installed ~/CLAUDE.md"
fi
echo ""

# Configure settings.json
echo "⚙️  Configuring settings.json..."
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  # Create new settings.json with hook
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/memory-guard.sh",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
EOF
  echo "  - Created settings.json with PostToolUse hook"
else
  echo "  ⚠️  settings.json already exists"
  echo "  Please manually add the following PostToolUse hook to your settings.json:"
  echo ""
  cat << 'EOF'
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/memory-guard.sh",
            "timeout": 10000
          }
        ]
      }
    ]
  }
EOF
  echo ""
fi

# Create default config
echo "⚙️  Creating default configuration..."
CONFIG_FILE="${CLAUDE_DIR}/memory-guard-config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" << 'EOF'
# Claude Code Memory Guard Configuration

# Enable/disable memory monitoring
MEMORY_GUARD_ENABLED=true

# Memory thresholds (MB)
WARNING_THRESHOLD_MB=4096
CRITICAL_THRESHOLD_MB=8192

# Check interval (every N tool uses)
CHECK_INTERVAL=5

# Maximum log file size (bytes)
MAX_LOG_SIZE=1048576
EOF
  echo "  - Created ~/.claude/memory-guard-config.env"
else
  echo "  - Configuration file already exists, skipping"
fi
echo ""

echo "========================================="
echo "✅ Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Restart Claude Code"
echo "2. Memory monitoring is now active"
echo "3. Use /memorystatus to check memory status"
echo ""
echo "Configuration: ~/.claude/memory-guard-config.env"
echo "Documentation: ~/CLAUDE.md"
echo "Logs: ~/.claude/memory-guard.log"
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""
