#!/bin/bash
# claude-code-memory-guard - Memory monitoring for Claude Code
# https://github.com/Gaku52/claude-code-memory-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${HOME}/.claude/memory-guard-config.env"
COUNTER_FILE="${HOME}/.claude/memory-guard-counter"

# Load defaults
MEMORY_GUARD_ENABLED=true
WARNING_THRESHOLD_MB=4096
CRITICAL_THRESHOLD_MB=8192
CHECK_INTERVAL=5
LOG_FILE="${HOME}/.claude/memory-guard.log"
MAX_LOG_SIZE=1048576

# Load user config if exists
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# Exit if disabled
if [[ "$MEMORY_GUARD_ENABLED" != "true" ]]; then
  exit 0
fi

# --- Counter-based throttling ---
count=0
if [[ -f "$COUNTER_FILE" ]]; then
  count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
fi
count=$((count + 1))

if [[ $count -lt $CHECK_INTERVAL ]]; then
  echo "$count" > "$COUNTER_FILE"
  exit 0
fi

# Reset counter
echo "0" > "$COUNTER_FILE"

# --- Log rotation ---
if [[ -f "$LOG_FILE" ]]; then
  log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
  if [[ $log_size -gt $MAX_LOG_SIZE ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
  fi
fi

# --- Memory measurement ---
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

# Sum RSS of all node processes (in KB from ps, convert to MB)
node_rss_kb=$(ps -eo rss,comm 2>/dev/null | grep -i node | awk '{sum += $1} END {print sum+0}')
node_rss_mb=$((node_rss_kb / 1024))

# macOS system memory pressure
mem_pressure="normal"
if command -v memory_pressure &>/dev/null; then
  pressure_output=$(memory_pressure 2>/dev/null | head -1 || echo "")
  if echo "$pressure_output" | grep -qi "critical"; then
    mem_pressure="critical"
  elif echo "$pressure_output" | grep -qi "warn"; then
    mem_pressure="warning"
  fi
fi

# --- Determine status ---
status="OK"
if [[ $node_rss_mb -ge $CRITICAL_THRESHOLD_MB ]] || [[ "$mem_pressure" == "critical" ]]; then
  status="CRITICAL"
elif [[ $node_rss_mb -ge $WARNING_THRESHOLD_MB ]] || [[ "$mem_pressure" == "warning" ]]; then
  status="WARNING"
fi

# --- Log entry ---
echo "[$timestamp] status=$status node_rss=${node_rss_mb}MB pressure=$mem_pressure" >> "$LOG_FILE"

# --- Output only on WARNING/CRITICAL ---
if [[ "$status" == "WARNING" ]]; then
  cat <<EOF
{"additionalContext": "⚠️ MEMORY WARNING: Node processes using ${node_rss_mb}MB (threshold: ${WARNING_THRESHOLD_MB}MB). System pressure: ${mem_pressure}. Actions required: 1) Run /compact to reduce context 2) Use partial file reads (limit/offset) instead of full reads 3) Delegate work to Task subagents 4) Avoid reading large files entirely"}
EOF
elif [[ "$status" == "CRITICAL" ]]; then
  cat <<EOF
{"additionalContext": "🚨 MEMORY CRITICAL: Node processes using ${node_rss_mb}MB (threshold: ${CRITICAL_THRESHOLD_MB}MB). System pressure: ${mem_pressure}. IMMEDIATE ACTIONS: 1) Run /compact NOW 2) STOP reading files - use only targeted Grep/Glob 3) Minimize tool calls 4) Complete current task and recommend session restart 5) Do NOT start new large operations"}
EOF
fi

exit 0
