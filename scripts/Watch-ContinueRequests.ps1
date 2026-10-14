[CmdletBinding()]
param([string] $ContinueDirectory = 'D:\Continue')

$ErrorActionPreference = 'Stop'
$dataDirectory = Join-Path $ContinueDirectory 'dev_data'
if (-not (Test-Path -LiteralPath $dataDirectory -PathType Container)) {
    throw 'Continue development data was not found. Open Continue and request a fresh completion first.'
}
$eventLog = Get-ChildItem -LiteralPath $dataDirectory -Filter 'tokensGenerated.jsonl' -File -Recurse |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $eventLog) { throw 'No tokensGenerated.jsonl exists yet. This log path was verified with Continue 2.0.0.' }

Write-Host 'Watching NEW Continue generation events. Ctrl+C stops watching.'
Write-Host 'These events prove a model request; separately check the suggestion and Tab in the editor.'
Get-Content -LiteralPath $eventLog.FullName -Tail 0 -Wait | ForEach-Object {
    $eventLine = $_
    try { $event = $eventLine | ConvertFrom-Json -ErrorAction Stop } catch { $event = $null }
    if ($event -and $event.eventName -eq 'tokensGenerated') {
        [ordered]@{
            timestamp = $event.timestamp
            provider = $event.provider
            model = $event.model
            generatedTokens = $event.generatedTokens
        } | ConvertTo-Json -Compress
    }
}
