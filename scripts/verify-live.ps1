# Prove what Claude Code actually sent to the model, from the session transcript.
# Run after restarting Claude Code and sending one message.
# Prints the real system-prompt block 0 and whether the refusal clause survived.
$ErrorActionPreference = 'Stop'

$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$root = Join-Path $claudeHome 'projects'
if (-not (Test-Path $root)) { Write-Host "no transcripts at $root"; exit 2 }

$files = Get-ChildItem $root -Recurse -Filter '*.jsonl' -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 8

$seen = 0
foreach ($f in $files) {
    $line = Select-String -Path $f.FullName -Pattern '"type":"api-request-shape"' -ErrorAction SilentlyContinue |
            Select-Object -Last 1
    if (-not $line) { continue }
    try { $shape = $line.Line | ConvertFrom-Json } catch { continue }
    $sys = $shape.shape.system
    if (-not $sys) { continue }

    $seen++
    $block0 = $sys[0].text
    $joined = ($sys | ForEach-Object { $_.text }) -join "`n"
    $armoredId   = $block0 -match 'Christina|Little Code Sauce'
    $cleanClause = $joined -notmatch 'Refuse requests for destructive'
    $mark = if ($armoredId -and $cleanClause) { 'ARMORED ' } else { 'RAW     ' }

    "{0} {1}  blocks={2}  {3}" -f $mark, $f.LastWriteTime.ToString('HH:mm:ss'), $sys.Count, $f.Name
    "         block0: " + $block0.Substring(0, [Math]::Min(90, $block0.Length)).Trim()
    if ($seen -ge 3) { break }
}
if ($seen -eq 0) { Write-Host 'no api-request-shape found yet - send one message in Claude Code first' }
