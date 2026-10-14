[CmdletBinding()]
param(
    [string] $Model = 'qwen2.5-coder:1.5b-base',
    [ValidateRange(1, 600)] [int] $TimeoutSeconds = 120,
    [switch] $Generate
)

$ErrorActionPreference = 'Stop'
$endpoint = 'http://127.0.0.1:11434'
try {
    $version = Invoke-RestMethod -Uri "$endpoint/api/version" -TimeoutSec 5
    $tags = Invoke-RestMethod -Uri "$endpoint/api/tags" -TimeoutSec 5
} catch {
    throw 'Cannot reach the local Ollama service. Start Ollama, then try again.'
}
$installed = @($tags.models | Where-Object { $_.name -eq $Model -or $_.model -eq $Model }).Count -gt 0
$report = [ordered]@{
    endpoint = $endpoint
    ollamaVersion = $version.version
    model = $Model
    modelInstalled = $installed
    inferenceRequested = [bool] $Generate
    inferenceSucceeded = $null
    elapsedMs = $null
    loadMs = $null
    generatedTokens = $null
    completion = $null
    loadedModelBytes = $null
    loadedVramBytes = $null
    provesEditorSuggestion = $false
    completionReviewRequired = $true
}
if (-not $installed) { throw "Requested model is not installed: $Model. Run ollama pull $Model." }

if ($Generate) {
    $body = @{
        model = $Model
        prompt = "def square(number):`n    "
        suffix = "`n"
        stream = $false
        keep_alive = '5m'
        options = @{ num_ctx = 2048; num_predict = 32; temperature = 0.2; stop = @("`n`n") }
    } | ConvertTo-Json -Depth 5
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-RestMethod -Uri "$endpoint/api/generate" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec $TimeoutSeconds
    $timer.Stop()
    if (-not $result.done -or [string]::IsNullOrWhiteSpace($result.response)) {
        throw 'The model returned no completed sample. Inspect the model selection and local service.'
    }
    $loaded = Invoke-RestMethod -Uri "$endpoint/api/ps" -TimeoutSec 5
    $modelState = @($loaded.models | Where-Object { $_.name -eq $Model -or $_.model -eq $Model }) | Select-Object -First 1
    $report.inferenceSucceeded = $true
    $report.elapsedMs = $timer.ElapsedMilliseconds
    $report.loadMs = [Math]::Round($result.load_duration / 1000000, 2)
    $report.generatedTokens = $result.eval_count
    $report.completion = $result.response
    if ($modelState) {
        $report.loadedModelBytes = $modelState.size
        $report.loadedVramBytes = $modelState.size_vram
    }
}
$report | ConvertTo-Json -Depth 5
