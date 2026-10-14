[CmdletBinding()]
param(
    [string] $Workspace = (Get-Location).Path,
    [string] $CodeCommand = 'code',
    [string] $OllamaExecutable = 'D:\Ollama\ollama.exe',
    [string] $ModelsDirectory = 'D:\Ollama\Models',
    [string] $ContinueDirectory = 'D:\Continue',
    [string] $ExtensionsDirectory = 'D:\VSCodeExtensions',
    [switch] $CheckOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Workspace -PathType Container)) {
    throw "Workspace directory does not exist: $Workspace"
}
if (-not (Test-Path -LiteralPath $OllamaExecutable -PathType Leaf)) {
    throw "Ollama executable was not found. Set -OllamaExecutable: $OllamaExecutable"
}
if (Test-Path -LiteralPath $CodeCommand -PathType Leaf) {
    $resolvedCode = (Resolve-Path -LiteralPath $CodeCommand).Path
} else {
    $resolvedCode = (Get-Command -Name $CodeCommand -CommandType Application -ErrorAction Stop).Source
}
$resolvedWorkspace = (Resolve-Path -LiteralPath $Workspace).Path
$modelsPath = [System.IO.Path]::GetFullPath($ModelsDirectory)
$continuePath = [System.IO.Path]::GetFullPath($ContinueDirectory)
$extensionsPath = [System.IO.Path]::GetFullPath($ExtensionsDirectory)
$configPath = Join-Path $continuePath 'config.yaml'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Continue config was not found. Copy the example config to: $configPath"
}

if ($CheckOnly) {
    [ordered]@{
        workspace = $resolvedWorkspace
        codeCommand = $resolvedCode
        ollamaExecutable = $OllamaExecutable
        modelsDirectory = $modelsPath
        continueDirectory = $continuePath
        extensionsDirectory = $extensionsPath
        configExists = $true
        mode = 'check-only: no process launched and no environment changed'
    } | ConvertTo-Json
    return
}

# A running VS Code can reuse its earlier environment. Let the user close it
# normally so that unsaved work is preserved.
if (Get-Process -Name Code -ErrorAction SilentlyContinue) {
    throw 'Close existing VS Code windows normally, then run this launcher again.'
}

$currentModelDirectory = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS', 'User')
if ($currentModelDirectory -and [System.IO.Path]::GetFullPath($currentModelDirectory) -ne $modelsPath) {
    Write-Warning 'The saved OLLAMA_MODELS differs from this launch. An already running Ollama keeps its old environment. Restart it normally if needed.'
}

# These variables affect this shell and its children. No persistent user
# settings, extension files, or existing model files are replaced.
$env:VSCODE_EXTENSIONS = $extensionsPath
$env:CONTINUE_GLOBAL_DIR = $continuePath
$env:OLLAMA_MODELS = $modelsPath
$env:OLLAMA_HOST = '127.0.0.1:11434'
foreach ($directory in @($modelsPath, $continuePath, $extensionsPath)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
}

$serverReady = $false
try {
    $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/version' -TimeoutSec 2
    $serverReady = $true
} catch {
    Start-Process -FilePath $OllamaExecutable -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/version' -TimeoutSec 2
            $serverReady = $true
            break
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
}
if (-not $serverReady) {
    throw 'Ollama did not become ready on 127.0.0.1:11434. Run ollama serve in a terminal to inspect its error.'
}

& $resolvedCode --extensions-dir $extensionsPath $resolvedWorkspace
if ($LASTEXITCODE -ne 0) { throw "VS Code launcher returned exit code $LASTEXITCODE." }
