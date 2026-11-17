# Remove the gauntlet: restore user memory and the original claude binary.
param([switch]$KeepMemory, [switch]$KeepBinary)
$ErrorActionPreference = 'Stop'

$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$backupDir = Join-Path $claudeHome 'amadeus-backup'

if (-not $KeepMemory) {
    $target = Join-Path $claudeHome 'CLAUDE.md'
    $bak = Get-ChildItem $backupDir -Filter 'CLAUDE.md.*.bak' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime | Select-Object -Last 1
    if ($bak) {
        Copy-Item $bak.FullName $target -Force
        Write-Host ("restored {0} <- {1}" -f $target, $bak.Name)
    } elseif (Test-Path $target) {
        Remove-Item $target -Force
        Write-Host ("removed {0} (no previous memory existed)" -f $target)
    } else { Write-Host 'no user memory to restore' }
}

if (-not $KeepBinary) {
    $locked = Get-Process claude -ErrorAction SilentlyContinue
    if ($locked) { throw ("claude is running (pid " + (($locked | ForEach-Object Id) -join ',') + "). Close every window, then rerun.") }
    $bak = Get-ChildItem $backupDir -Filter 'claude.exe.*.bak' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $bak) { Write-Warning 'no binary backup found; nothing restored' }
    else {
        $exe = Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe'
        if (-not (Test-Path $exe)) {
            try { $npmRoot = (& npm root -g 2>$null); $exe = Join-Path $npmRoot '@anthropic-ai\claude-code\bin\claude.exe' } catch { }
        }
        if (-not (Test-Path $exe)) { throw 'claude binary not found' }
        Copy-Item $bak.FullName $exe -Force
        Write-Host ("restored {0} <- {1} ({2:N0} bytes)" -f $exe, $bak.Name, (Get-Item $exe).Length)
    }
}

Write-Host ''
Write-Host 'Uninstalled. Restart Claude Code to load the stock prompt.'
