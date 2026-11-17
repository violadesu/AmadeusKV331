# Is the installed Claude Code binary armored right now?
# Reads the binary, looks for the identity constants, reports a verdict.
# Exit codes: 0 armored, 1 not armored, 2 unknown build.
param([string]$Exe)
$ErrorActionPreference = 'Stop'

if (-not ('CCPatch.Finder' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
namespace CCPatch {
    public static class Finder {
        public static int[] FindAll(byte[] hay, byte[] needle) {
            var hits = new List<int>();
            if (needle == null || needle.Length == 0 || hay.Length < needle.Length) return hits.ToArray();
            byte first = needle[0];
            int limit = hay.Length - needle.Length;
            for (int i = 0; i <= limit; i++) {
                if (hay[i] != first) continue;
                bool ok = true;
                for (int j = 1; j < needle.Length; j++) {
                    if (hay[i + j] != needle[j]) { ok = false; break; }
                }
                if (ok) hits.Add(i);
            }
            return hits.ToArray();
        }
    }
}
'@
}

$candidates = @()
if ($Exe) {
    if (-not (Test-Path $Exe)) { Write-Host ("not found: {0}" -f $Exe); exit 2 }
    $candidates = @($Exe)
}
else {
    try { $npmRoot = (& npm root -g 2>$null); if ($npmRoot) { $candidates += (Join-Path $npmRoot '@anthropic-ai\claude-code\bin\claude.exe') } } catch { }
    $candidates += @(
        (Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\claude\claude.exe'),
        (Join-Path $env:LOCALAPPDATA 'claude\claude.exe'),
        (Join-Path $env:USERPROFILE '.claude\local\claude.exe')
    )
}
$exePath = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $exePath) { Write-Host 'claude binary not found'; exit 2 }

$pkgJson = Join-Path (Split-Path (Split-Path $exePath -Parent) -Parent) 'package.json'
$version = if (Test-Path $pkgJson) { (Get-Content $pkgJson -Raw | ConvertFrom-Json).version } else { 'unknown' }

$bytes = [System.IO.File]::ReadAllBytes($exePath)
$enc = [System.Text.Encoding]::UTF8
$armored = [CCPatch.Finder]::FindAll($bytes, $enc.GetBytes('You are Christina')).Length
$stock   = [CCPatch.Finder]::FindAll($bytes, $enc.GetBytes("You are Claude Code, Anthropic's official")).Length
$refusal = [CCPatch.Finder]::FindAll($bytes, $enc.GetBytes('Refuse requests for destructive techniques')).Length

Write-Host ("binary  : {0}" -f $exePath)
Write-Host ("version : {0}" -f $version)
Write-Host ("armored identity copies : {0}" -f $armored)
Write-Host ("stock   identity copies : {0}" -f $stock)
Write-Host ("refusal clause copies   : {0}" -f $refusal)
Write-Host ''

if ($armored -gt 0 -and $stock -eq 0 -and $refusal -eq 0) {
    Write-Host 'ARMORED'
    exit 0
}
if ($stock -gt 0) {
    Write-Host 'NOT ARMORED - an auto-update probably replaced the binary.'
    Write-Host ("rerun: powershell -ExecutionPolicy Bypass -File `"{0}`" -Apply" -f (Join-Path $PSScriptRoot 'patch-system-prompt.ps1'))
    exit 1
}
Write-Host 'UNKNOWN - this build does not carry the expected constants.'
exit 2
