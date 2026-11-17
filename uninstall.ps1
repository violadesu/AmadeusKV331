# Remove the gauntlet: restore user memory and a stock claude binary.
# The binary comes back from a reinstall of the same npm package version; the
# oldest backup is only a fallback for offline or non-npm installs.
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

    # Reinstall the same version from npm: that is the only reliable way back to
    # the stock binary when every backup on disk is already armored.
    $npmRoot = $null
    try { $npmRoot = (& npm root -g 2>$null) } catch { }
    if (-not $npmRoot -and (Test-Path (Join-Path $env:APPDATA 'npm\node_modules'))) {
        $npmRoot = Join-Path $env:APPDATA 'npm\node_modules'
    }
    $npmExe = if ($npmRoot) { Join-Path $npmRoot '@anthropic-ai\claude-code\bin\claude.exe' } else { $null }
    $pkgJson = if ($npmRoot) { Join-Path $npmRoot '@anthropic-ai\claude-code\package.json' } else { $null }
    $version = if ($pkgJson -and (Test-Path $pkgJson)) { (Get-Content $pkgJson -Raw | ConvertFrom-Json).version } else { '' }
    $spec = if ($version) { '@anthropic-ai/claude-code@' + $version } else { '@anthropic-ai/claude-code' }

    $restored = $false
    if ($npmRoot -and (Test-Path (Join-Path $npmRoot '@anthropic-ai\claude-code'))) {
        Write-Host ("reinstalling {0} from npm - this restores the stock binary" -f $spec)
        & npm install -g $spec --no-audit --no-fund
        if ($LASTEXITCODE -eq 0) {
            $probe = if ($Exe) { $Exe } elseif (Test-Path $npmExe) { $npmExe } else { $null }
            if ($probe -and (Test-Path $probe)) {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'scripts\check-armor.ps1') -Exe $probe
                # exit 0 means armor survived; 1 (stock) or 2 (unknown build) means it did not
                if ($LASTEXITCODE -ne 0) { $restored = $true }
                else { Write-Warning ("{0} still carries armor after reinstall" -f $probe) }
            } else { Write-Warning 'reinstalled, but no binary was found to verify' }
        } else { Write-Warning 'npm reinstall failed' }
    } else {
        Write-Warning 'no npm-managed claude package found'
    }

    if (-not $restored) {
        Write-Host 'falling back to the oldest binary backup'
        $bak = Get-ChildItem $backupDir -Filter 'claude.exe.*.bak' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime | Select-Object -First 1
        if (-not $bak) { Write-Warning 'no binary backup found; nothing restored' }
        else {
            if ($Exe) { $candidates = @($Exe) }
            else {
                $candidates = @()
                if ($npmExe) { $candidates += $npmExe }
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
            Write-Host 'note: a fallback backup can itself contain armor on machines armored before this installer existed'
        }
    }
}

Write-Host ''
Write-Host 'Uninstalled. Restart Claude Code to load the stock prompt.'
