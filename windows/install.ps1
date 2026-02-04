#Requires -Version 7.0
# claude-code-memory-guard installer (Windows)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$RepoDir = Split-Path $ScriptDir -Parent
$ClaudeDir = Join-Path $HOME '.claude'
$SettingsFile = Join-Path $ClaudeDir 'settings.json'
$ClaudeMD = Join-Path $HOME 'CLAUDE.md'

Write-Host '=== claude-code-memory-guard installer (Windows) ===' -ForegroundColor Cyan
Write-Host ''

# 1. Ensure ~/.claude/
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}
Write-Host '[1/5] ~/.claude/ directory ready' -ForegroundColor Green

# 2. Copy script
Copy-Item (Join-Path $ScriptDir 'memory-guard.ps1') (Join-Path $ClaudeDir 'memory-guard.ps1') -Force
Write-Host '[2/5] memory-guard.ps1 installed' -ForegroundColor Green

# 3. Copy config
$configDest = Join-Path $ClaudeDir 'memory-guard-config.env'
if (-not (Test-Path $configDest)) {
    Copy-Item (Join-Path $RepoDir 'config.env') $configDest
    Write-Host '[3/5] Default config installed' -ForegroundColor Green
}
else {
    Write-Host '[3/5] Config already exists, skipping' -ForegroundColor Yellow
}

# 4. Merge hook into settings.json
$hookCommand = 'pwsh -NoProfile -File "{0}"' -f (Join-Path $ClaudeDir 'memory-guard.ps1')
$hookEntry = @{
    type    = 'command'
    command = $hookCommand
    timeout = 10000
}

if (Test-Path $SettingsFile) {
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json -AsHashtable

    # Check if hook already exists
    $hookExists = $false
    if ($settings.ContainsKey('hooks') -and $settings['hooks'].ContainsKey('PostToolUse')) {
        foreach ($rule in $settings['hooks']['PostToolUse']) {
            foreach ($h in $rule['hooks']) {
                if ($h['command'] -like '*memory-guard*') {
                    $hookExists = $true
                    break
                }
            }
        }
    }

    if ($hookExists) {
        Write-Host '[4/5] Hook already registered, skipping' -ForegroundColor Yellow
    }
    else {
        if (-not $settings.ContainsKey('hooks')) { $settings['hooks'] = @{} }
        if (-not $settings['hooks'].ContainsKey('PostToolUse')) { $settings['hooks']['PostToolUse'] = @() }
        $settings['hooks']['PostToolUse'] += @{
            matcher = ''
            hooks   = @($hookEntry)
        }
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding utf8
        Write-Host '[4/5] Hook added to settings.json' -ForegroundColor Green
    }
}
else {
    $settings = @{
        hooks = @{
            PostToolUse = @(
                @{
                    matcher = ''
                    hooks   = @($hookEntry)
                }
            )
        }
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding utf8
    Write-Host '[4/5] Created settings.json with hook' -ForegroundColor Green
}

# 5. Append CLAUDE.md rules
$marker = '# Memory Management Rules (claude-code-memory-guard)'
$snippetPath = Join-Path $RepoDir 'claude-md-snippet.md'

if (Test-Path $ClaudeMD) {
    $content = Get-Content $ClaudeMD -Raw
    if ($content -like "*$marker*") {
        Write-Host '[5/5] Memory rules already in CLAUDE.md, skipping' -ForegroundColor Yellow
    }
    else {
        $snippet = Get-Content $snippetPath -Raw
        Add-Content -Path $ClaudeMD -Value "`n$snippet"
        Write-Host '[5/5] Memory rules appended to CLAUDE.md' -ForegroundColor Green
    }
}
else {
    Copy-Item $snippetPath $ClaudeMD
    Write-Host '[5/5] Created CLAUDE.md with memory rules' -ForegroundColor Green
}

# Verification
Write-Host ''
Write-Host '=== Verifying ===' -ForegroundColor Cyan
$errors = 0

$guardScript = Join-Path $ClaudeDir 'memory-guard.ps1'
if (Test-Path $guardScript) { Write-Host '  ✓ Script installed' -ForegroundColor Green }
else { Write-Host '  ✗ Script missing' -ForegroundColor Red; $errors++ }

if (Test-Path $configDest) { Write-Host '  ✓ Config exists' -ForegroundColor Green }
else { Write-Host '  ✗ Config missing' -ForegroundColor Red; $errors++ }

if ((Test-Path $SettingsFile) -and ((Get-Content $SettingsFile -Raw) -like '*memory-guard*')) {
    Write-Host '  ✓ Hook registered' -ForegroundColor Green
}
else { Write-Host '  ✗ Hook missing' -ForegroundColor Red; $errors++ }

if ((Test-Path $ClaudeMD) -and ((Get-Content $ClaudeMD -Raw) -like "*$marker*")) {
    Write-Host '  ✓ CLAUDE.md rules' -ForegroundColor Green
}
else { Write-Host '  ✗ CLAUDE.md rules missing' -ForegroundColor Red; $errors++ }

Write-Host ''
if ($errors -eq 0) {
    Write-Host 'All checks passed. Memory guard is active.' -ForegroundColor Green
    Write-Host ''
    Write-Host "Customize: edit $configDest"
    Write-Host "Logs: Get-Content $($ClaudeDir)\memory-guard.log"
}
else {
    Write-Host "WARNING: $errors check(s) failed." -ForegroundColor Red
}
