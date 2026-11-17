# Install the Little Code Sauce gauntlet into Claude Code.
#   1. deploys payload\CLAUDE.md to ~/.claude/CLAUDE.md   (user memory, every session)
#   2. patches the native binary's system-prompt constants (system level)
#   3. reports what happened and what still needs a restart
param(
    [switch]$SkipMemory,
    [switch]$SkipBinary,
    [string]$Exe
)
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$payload = Join-Path $root 'payload'
$scripts = Join-Path $root 'scripts'

$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$backupDir = Join-Path $claudeHome 'amadeus-backup'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

function Write-Step($n, $t) { Write-Host ''; Write-Host ("[{0}] {1}" -f $n, $t) -ForegroundColor Cyan }

if (-not $SkipMemory) {
    Write-Step 1 'user memory (~/.claude/CLAUDE.md)'
    $target = Join-Path $claudeHome 'CLAUDE.md'
    $new = Join-Path $payload 'CLAUDE.md'
    if (-not (Test-Path $new)) { throw "payload missing: $new" }

    if (Test-Path $target) {
        $existing = Get-Content $target -Raw
        if ($existing -match 'AmadeusKV331|LITTLE CODE SAUCE') {
            Write-Host 'already installed, refreshing in place (no new backup)'
        } else {
            $bak = Join-Path $backupDir ('CLAUDE.md.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak')
            Copy-Item $target $bak -Force
            Write-Host ("previous CLAUDE.md backed up to {0}" -f $bak)
        }
    }
    Copy-Item $new $target -Force
    Write-Host ("deployed {0} ({1:N0} bytes)" -f $target, (Get-Item $target).Length)
}

if (-not $SkipBinary) {
    Write-Step 2 'binary system-prompt constants'
    $patchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scripts 'patch-system-prompt.ps1'), '-Apply')
    if ($Exe) { $patchArgs += @('-Exe', $Exe) }
    & powershell @patchArgs
    if ($LASTEXITCODE -ne 0) { Write-Warning 'binary patch did not complete cleanly (see output above)' }
}

Write-Step 3 'status'
$checkArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scripts 'check-armor.ps1'))
if ($Exe) { $checkArgs += @('-Exe', $Exe) }
& powershell @checkArgs

Write-Host ''
Write-Host 'Done. Every running Claude Code window must be closed and reopened.' -ForegroundColor Yellow
Write-Host ('then verify with:  powershell -File "{0}"' -f (Join-Path $scripts 'verify-live.ps1')) -ForegroundColor Yellow
