#Requires -Version 7.0
# claude-code-memory-guard uninstaller (Windows)

$ErrorActionPreference = 'SilentlyContinue'

$ClaudeDir = Join-Path $HOME '.claude'
$SettingsFile = Join-Path $ClaudeDir 'settings.json'
$ClaudeMD = Join-Path $HOME 'CLAUDE.md'

Write-Host '=== claude-code-memory-guard uninstaller (Windows) ===' -ForegroundColor Cyan
Write-Host ''

# 1. Remove script
Remove-Item (Join-Path $ClaudeDir 'memory-guard.ps1') -Force -ErrorAction SilentlyContinue
Write-Host '[1/5] Removed memory-guard.ps1' -ForegroundColor Green

# 2. Remove config
Remove-Item (Join-Path $ClaudeDir 'memory-guard-config.env') -Force -ErrorAction SilentlyContinue
Write-Host '[2/5] Removed config' -ForegroundColor Green

# 3. Remove counter
Remove-Item (Join-Path $ClaudeDir 'memory-guard-counter') -Force -ErrorAction SilentlyContinue
Write-Host '[3/5] Removed counter' -ForegroundColor Green

# 4. Remove hook from settings.json
if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json -AsHashtable
        if ($settings.ContainsKey('hooks') -and $settings['hooks'].ContainsKey('PostToolUse')) {
            $settings['hooks']['PostToolUse'] = @(
                $settings['hooks']['PostToolUse'] | Where-Object {
                    $dominated = $false
                    foreach ($h in $_['hooks']) {
                        if ($h['command'] -like '*memory-guard*') { $dominated = $true }
                    }
                    -not $dominated
                }
            )
            if ($settings['hooks']['PostToolUse'].Count -eq 0) {
                $settings['hooks'].Remove('PostToolUse')
            }
            if ($settings['hooks'].Count -eq 0) {
                $settings.Remove('hooks')
            }
            $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding utf8
        }
        Write-Host '[4/5] Removed hook from settings.json' -ForegroundColor Green
    }
    catch {
        Write-Host '[4/5] Could not update settings.json' -ForegroundColor Yellow
    }
}
else {
    Write-Host '[4/5] No settings.json found' -ForegroundColor Yellow
}

# 5. Remove CLAUDE.md rules
$markerStart = '# Memory Management Rules (claude-code-memory-guard)'
$markerEnd = '- Avoid accumulating large amounts of file content in conversation context'

if (Test-Path $ClaudeMD) {
    $lines = Get-Content $ClaudeMD
    $inBlock = $false
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -like "*$markerStart*") {
            $inBlock = $true
            continue
        }
        if ($inBlock -and $line -like "*$markerEnd*") {
            $inBlock = $false
            continue
        }
        if (-not $inBlock) {
            $newLines += $line
        }
    }
    # Remove trailing empty lines
    while ($newLines.Count -gt 0 -and $newLines[-1].Trim() -eq '') {
        $newLines = $newLines[0..($newLines.Count - 2)]
    }
    $newLines | Set-Content $ClaudeMD -Encoding utf8
    Write-Host '[5/5] Removed CLAUDE.md rules' -ForegroundColor Green
}
else {
    Write-Host '[5/5] No CLAUDE.md found' -ForegroundColor Yellow
}

# Cleanup logs
Remove-Item (Join-Path $ClaudeDir 'memory-guard.log') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ClaudeDir 'memory-guard.log.old') -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '=== Uninstallation complete ===' -ForegroundColor Cyan
