# Remove the gauntlet: restore user memory and the original claude binary.
param([switch]$KeepMemory, [switch]$KeepBinary, [string]$Exe)
$ErrorActionPreference = 'Stop'

$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$backupDir = Join-Path $claudeHome 'amadeus-backup'

if (-not $KeepMemory) {
    $target = Join-Path $claudeHome 'CLAUDE.md'
    # Prefer the newest backup that does not already contain the armor header:
    # older installers could back up an armored file, which must not be restored.
    $baks = @(Get-ChildItem $backupDir -Filter 'CLAUDE.md.*.bak' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime)
    $clean = @($baks | Where-Object {
        $text = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $text -and $text -notmatch 'AmadeusKV331|LITTLE CODE SAUCE'
    })
    $bak = if ($clean.Count -gt 0) { $clean[-1] } elseif ($baks.Count -gt 0) { $baks[0] } else { $null }
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
    # The oldest backup is the state before the first patch; newer ones may already
    # carry armor written by a previous run.
    $bak = Get-ChildItem $backupDir -Filter 'claude.exe.*.bak' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime | Select-Object -First 1
    if (-not $bak) { Write-Warning 'no binary backup found; nothing restored' }
    else {
        if ($Exe) { $candidates = @($Exe) }
        else {
            $candidates = @()
            try { $npmRoot = (& npm root -g 2>$null); if ($npmRoot) { $candidates += (Join-Path $npmRoot '@anthropic-ai\claude-code\bin\claude.exe') } } catch { }
            $candidates += @(
                (Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe'),
                (Join-Path $env:LOCALAPPDATA 'Programs\claude\claude.exe'),
                (Join-Path $env:LOCALAPPDATA 'claude\claude.exe'),
                (Join-Path $env:USERPROFILE '.claude\local\claude.exe')
            )
        }
        $exe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        if (-not $exe) { throw 'claude binary not found' }
        Copy-Item $bak.FullName $exe -Force
        Write-Host ("restored {0} <- {1} ({2:N0} bytes)" -f $exe, $bak.Name, (Get-Item $exe).Length)
    }
}

Write-Host ''
Write-Host 'Uninstalled. Restart Claude Code to load the stock prompt.'
