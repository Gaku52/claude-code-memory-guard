# claude-code-memory-guard

Automatic memory monitoring and management for Claude Code on macOS. Prevents memory bloat (100GB+) through PostToolUse hooks, configurable thresholds, and self-regulating CLAUDE.md rules.

## The Problem

Claude Code sessions can consume excessive memory over time, with Node.js processes sometimes growing beyond 100GB. This happens gradually and often goes unnoticed until the system becomes unresponsive, swap usage explodes, or the session crashes.

## How It Works

Three components work together:

1. **PostToolUse Hook** (`memory-guard.sh`) — Runs automatically after every Nth tool call. Measures total Node.js RSS memory and macOS memory pressure. Outputs warnings as `additionalContext` JSON that Claude sees in its tool results.

2. **CLAUDE.md Rules** (`claude-md-snippet.md`) — Instructions that tell Claude how to respond when it sees memory warnings. On WARNING: compact context, use partial reads, delegate to subagents. On CRITICAL: stop file reads, minimize operations, recommend restart.

3. **Config** (`config.env`) — User-adjustable thresholds, check frequency, and enable/disable toggle.

### Flow

```
Tool call completes
  → PostToolUse hook fires
    → Counter check (skip if not Nth call)
    → Measure node RSS + memory_pressure
    → OK: silent (no output)
    → WARNING/CRITICAL: output JSON additionalContext
      → Claude reads the warning
        → Claude follows CLAUDE.md rules to reduce memory usage
```

## Requirements

- macOS (uses `ps` and `memory_pressure` commands)
- Claude Code CLI
- `jq` (recommended, for safe settings.json merging) — `brew install jq`

## Installation

```bash
git clone https://github.com/Gaku52/claude-code-memory-guard.git
cd claude-code-memory-guard
bash install.sh
```

The installer:
- Copies `memory-guard.sh` to `~/.claude/`
- Creates default config at `~/.claude/memory-guard-config.env`
- Adds the PostToolUse hook to `~/.claude/settings.json` (safely merges with existing settings)
- Appends memory management rules to `~/CLAUDE.md` (skips if already present)

## Uninstallation

```bash
cd claude-code-memory-guard
bash uninstall.sh
```

Cleanly removes all installed files, hooks, and CLAUDE.md rules.

## Configuration

Edit `~/.claude/memory-guard-config.env`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MEMORY_GUARD_ENABLED` | `true` | Enable/disable the guard |
| `WARNING_THRESHOLD_MB` | `4096` | Warning at 4GB Node.js RSS |
| `CRITICAL_THRESHOLD_MB` | `8192` | Critical at 8GB Node.js RSS |
| `CHECK_INTERVAL` | `5` | Check every 5th tool call |
| `LOG_FILE` | `~/.claude/memory-guard.log` | Log file path |
| `MAX_LOG_SIZE` | `1048576` | Rotate log at 1MB |

### Adjusting Thresholds

- **Lower thresholds** (e.g., WARNING=2048, CRITICAL=4096): More aggressive, catches issues earlier. Good for machines with limited RAM (8-16GB).
- **Higher thresholds** (e.g., WARNING=8192, CRITICAL=16384): More lenient. Good for machines with 32GB+ RAM.
- **CHECK_INTERVAL**: Higher values (10-20) reduce overhead but check less often. Lower values (1-3) catch spikes faster but add more overhead per tool call.

## What Claude Does When Warned

### ⚠️ WARNING Level
- Runs `/compact` to reduce conversation context
- Switches to partial file reads (using offset/limit parameters)
- Delegates subtasks to Task subagents
- Avoids reading large files entirely

### 🚨 CRITICAL Level
- Runs `/compact` immediately
- Stops all file read operations
- Uses only Grep/Glob for targeted searches
- Completes current task and recommends session restart
- Refuses to start new large operations

## Diagnostics

View the log to see memory trends:

```bash
cat ~/.claude/memory-guard.log
```

Example log entries:
```
[2026-02-04 11:30:15] status=OK node_rss=1200MB pressure=normal
[2026-02-04 11:35:42] status=WARNING node_rss=4500MB pressure=normal
[2026-02-04 11:40:01] status=CRITICAL node_rss=9200MB pressure=warning
```

## Manual Testing

Test the script directly:

```bash
# Run the script (resets counter, forces a check)
echo "4" > ~/.claude/memory-guard-counter
bash ~/.claude/memory-guard.sh

# Check the log
cat ~/.claude/memory-guard.log
```

## Troubleshooting

### Hook not firing
- Verify the hook is in `~/.claude/settings.json`: `cat ~/.claude/settings.json | jq '.hooks'`
- Check the script is executable: `ls -la ~/.claude/memory-guard.sh`
- Restart Claude Code after installing

### False positives
- Increase `WARNING_THRESHOLD_MB` in the config
- Increase `CHECK_INTERVAL` to reduce frequency

### Script errors
- Run manually to see errors: `bash -x ~/.claude/memory-guard.sh`
- Check the log: `cat ~/.claude/memory-guard.log`

### Want to temporarily disable
```bash
# Edit config
sed -i '' 's/MEMORY_GUARD_ENABLED=true/MEMORY_GUARD_ENABLED=false/' ~/.claude/memory-guard-config.env
```

## License

MIT
