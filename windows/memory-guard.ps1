#Requires -Version 7.0
# claude-code-memory-guard - Memory monitoring for Claude Code (Windows)
# https://github.com/Gaku52/claude-code-memory-guard

$ErrorActionPreference = 'SilentlyContinue'

$ClaudeDir = Join-Path $HOME '.claude'
$ConfigFile = Join-Path $ClaudeDir 'memory-guard-config.env'
$CounterFile = Join-Path $ClaudeDir 'memory-guard-counter'
$LogFile = Join-Path $ClaudeDir 'memory-guard.log'

# --- Defaults ---
$Config = @{
    MEMORY_GUARD_ENABLED = 'true'
    WARNING_THRESHOLD_MB = 4096
    CRITICAL_THRESHOLD_MB = 8192
    CHECK_INTERVAL = 5
    MAX_LOG_SIZE = 1048576
    SYSTEM_FREE_WARN_PCT = 20
    SYSTEM_FREE_CRIT_PCT = 10
}

# --- Load user config (.env format) ---
if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) {
                $Config[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    }
}

# Exit if disabled
if ($Config['MEMORY_GUARD_ENABLED'] -ne 'true') {
    exit 0
}

$CheckInterval = [int]$Config['CHECK_INTERVAL']

# --- Counter-based throttling ---
$count = 0
if (Test-Path $CounterFile) {
    $count = [int](Get-Content $CounterFile -ErrorAction SilentlyContinue)
}
$count++

if ($count -lt $CheckInterval) {
    Set-Content -Path $CounterFile -Value $count -NoNewline
    exit 0
}
Set-Content -Path $CounterFile -Value '0' -NoNewline

# --- Log rotation ---
$MaxLogSize = [long]$Config['MAX_LOG_SIZE']
if (Test-Path $LogFile) {
    $logInfo = Get-Item $LogFile
    if ($logInfo.Length -gt $MaxLogSize) {
        Move-Item -Path $LogFile -Destination "$LogFile.old" -Force
    }
}

# --- Memory measurement ---
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$WarningMB = [int]$Config['WARNING_THRESHOLD_MB']
$CriticalMB = [int]$Config['CRITICAL_THRESHOLD_MB']
$FreeWarnPct = [int]$Config['SYSTEM_FREE_WARN_PCT']
$FreeCritPct = [int]$Config['SYSTEM_FREE_CRIT_PCT']

# Node.js process memory (WorkingSet64 -> MB)
$nodeProcesses = Get-Process -Name 'node' -ErrorAction SilentlyContinue
$nodeRssBytes = 0
if ($nodeProcesses) {
    $nodeRssBytes = ($nodeProcesses | Measure-Object -Property WorkingSet64 -Sum).Sum
}
$nodeRssMB = [math]::Floor($nodeRssBytes / 1MB)

# System free memory percentage
$sysPressure = 'normal'
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = $os.TotalVisibleMemorySize  # KB
    $freeMem = $os.FreePhysicalMemory       # KB
    $freePct = [math]::Round(($freeMem / $totalMem) * 100, 1)

    if ($freePct -le $FreeCritPct) {
        $sysPressure = 'critical'
    }
    elseif ($freePct -le $FreeWarnPct) {
        $sysPressure = 'warning'
    }
}
catch {
    $freePct = -1
}

# --- Determine status ---
$status = 'OK'
if ($nodeRssMB -ge $CriticalMB -or $sysPressure -eq 'critical') {
    $status = 'CRITICAL'
}
elseif ($nodeRssMB -ge $WarningMB -or $sysPressure -eq 'warning') {
    $status = 'WARNING'
}

# --- Log ---
$logEntry = "[$timestamp] status=$status node_rss=${nodeRssMB}MB sys_free=${freePct}% pressure=$sysPressure"
Add-Content -Path $LogFile -Value $logEntry

# --- Output (only on WARNING/CRITICAL) ---
if ($status -eq 'WARNING') {
    $msg = "⚠️ MEMORY WARNING: Node processes using ${nodeRssMB}MB (threshold: ${WarningMB}MB). System free: ${freePct}%. Actions required: 1) Run /compact to reduce context 2) Use partial file reads (limit/offset) instead of full reads 3) Delegate work to Task subagents 4) Avoid reading large files entirely"
    Write-Output "{`"additionalContext`": `"$msg`"}"
}
elseif ($status -eq 'CRITICAL') {
    $msg = "🚨 MEMORY CRITICAL: Node processes using ${nodeRssMB}MB (threshold: ${CriticalMB}MB). System free: ${freePct}%. IMMEDIATE ACTIONS: 1) Run /compact NOW 2) STOP reading files - use only targeted Grep/Glob 3) Minimize tool calls 4) Complete current task and recommend session restart 5) Do NOT start new large operations"
    Write-Output "{`"additionalContext`": `"$msg`"}"
}

exit 0
