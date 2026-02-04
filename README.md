# claude-code-memory-guard

Automatic memory monitoring and management for Claude Code. Prevents memory bloat (100GB+) through PostToolUse hooks, configurable thresholds, and self-regulating CLAUDE.md rules.

**Supports macOS and Windows (PowerShell 7).**

## The Problem

Claude Code sessions can consume excessive memory over time, with Node.js processes sometimes growing beyond 100GB. This happens gradually and often goes unnoticed until the system becomes unresponsive, swap usage explodes, or the session crashes.

## How It Works

Three components work together:

1. **PostToolUse Hook** — Runs automatically after every Nth tool call. Measures total Node.js process memory and system memory pressure. Outputs warnings as `additionalContext` JSON that Claude sees in its tool results.

2. **CLAUDE.md Rules** — Instructions that tell Claude how to respond when it sees memory warnings. On WARNING: compact context, use partial reads, delegate to subagents. On CRITICAL: stop file reads, minimize operations, recommend restart.

3. **Config** (`config.env`) — User-adjustable thresholds, check frequency, and enable/disable toggle. Shared format across both OSes.

### Flow

```
Tool call completes
  → PostToolUse hook fires
    → Counter check (skip if not Nth call)
    → Measure node process memory + system memory
    → OK: silent (no output)
    → WARNING/CRITICAL: output JSON additionalContext
      → Claude reads the warning
        → Claude follows CLAUDE.md rules to reduce memory usage
```

### Platform Details

| | macOS | Windows |
|---|---|---|
| Script | `memory-guard.sh` (bash) | `memory-guard.ps1` (PowerShell 7) |
| Process memory | `ps -eo rss,comm` (RSS) | `Get-Process -Name node` (WorkingSet64) |
| System memory | `memory_pressure` command | `Get-CimInstance Win32_OperatingSystem` |
| Hook command | `bash ~/.claude/memory-guard.sh` | `pwsh -NoProfile -File ~/.claude/memory-guard.ps1` |

## Requirements

### macOS
- Claude Code CLI
- `jq` (recommended) — `brew install jq`

### Windows
- Claude Code CLI
- PowerShell 7+ (`pwsh`) — [Install guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

## Installation

### macOS

```bash
git clone https://github.com/Gaku52/claude-code-memory-guard.git
cd claude-code-memory-guard
bash macos/install.sh
```

### Windows (PowerShell 7)

```powershell
git clone https://github.com/Gaku52/claude-code-memory-guard.git
cd claude-code-memory-guard
pwsh windows/install.ps1
```

The installer:
- Copies the monitoring script to `~/.claude/`
- Creates default config at `~/.claude/memory-guard-config.env`
- Adds the PostToolUse hook to `~/.claude/settings.json` (safely merges with existing settings)
- Appends memory management rules to `~/CLAUDE.md` (skips if already present)

## Uninstallation

### macOS
```bash
bash macos/uninstall.sh
```

### Windows
```powershell
pwsh windows/uninstall.ps1
```

Cleanly removes all installed files, hooks, and CLAUDE.md rules.

## Configuration

Edit `~/.claude/memory-guard-config.env`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MEMORY_GUARD_ENABLED` | `true` | Enable/disable the guard |
| `WARNING_THRESHOLD_MB` | `4096` | Warning at 4GB node process memory |
| `CRITICAL_THRESHOLD_MB` | `8192` | Critical at 8GB node process memory |
| `CHECK_INTERVAL` | `5` | Check every 5th tool call |
| `MAX_LOG_SIZE` | `1048576` | Rotate log at 1MB |
| `SYSTEM_FREE_WARN_PCT` | `20` | System free memory warning (%) |
| `SYSTEM_FREE_CRIT_PCT` | `10` | System free memory critical (%) |

### Adjusting Thresholds

- **Lower thresholds** (WARNING=2048, CRITICAL=4096): More aggressive. Good for 8-16GB RAM machines.
- **Higher thresholds** (WARNING=8192, CRITICAL=16384): More lenient. Good for 32GB+ RAM machines.
- **CHECK_INTERVAL**: Higher values (10-20) reduce overhead. Lower values (1-3) catch spikes faster.

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
# macOS
cat ~/.claude/memory-guard.log

# Windows
Get-Content ~/.claude/memory-guard.log
```

Example log entries:
```
[2026-02-04 11:30:15] status=OK node_rss=1200MB pressure=normal
[2026-02-04 11:35:42] status=WARNING node_rss=4500MB sys_free=18.2% pressure=warning
[2026-02-04 11:40:01] status=CRITICAL node_rss=9200MB sys_free=7.5% pressure=critical
```

## Troubleshooting

### Hook not firing
- Verify the hook exists in `~/.claude/settings.json`
- Check the script is in `~/.claude/`
- Restart Claude Code after installing

### False positives
- Increase `WARNING_THRESHOLD_MB` in config
- Increase `CHECK_INTERVAL` to reduce frequency

### Script errors
```bash
# macOS
bash -x ~/.claude/memory-guard.sh

# Windows
pwsh -File ~/.claude/memory-guard.ps1 -Verbose
```

### Temporarily disable
Edit `~/.claude/memory-guard-config.env` and set `MEMORY_GUARD_ENABLED=false`

## Repository Structure

```
claude-code-memory-guard/
├── README.md                  # This file
├── LICENSE                    # MIT
├── .gitignore
├── config.env                 # Shared config template
├── claude-md-snippet.md       # CLAUDE.md memory rules
├── hooks-config.json          # Hook definitions (both OS)
├── macos/
│   ├── memory-guard.sh        # Core monitoring script
│   ├── install.sh             # Installer
│   └── uninstall.sh           # Uninstaller
└── windows/
    ├── memory-guard.ps1       # Core monitoring script
    ├── install.ps1            # Installer
    └── uninstall.ps1          # Uninstaller
```

## License

MIT
