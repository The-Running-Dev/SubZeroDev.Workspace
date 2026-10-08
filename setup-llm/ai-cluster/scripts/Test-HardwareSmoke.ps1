[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Model,
    [int]$Runs,
    [int]$ContextTokens,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isCi = ($env:CI -eq 'true') -or ($env:GITHUB_ACTIONS -eq 'true')
$runFlag = $env:AI_CLUSTER_RUN_HARDWARE_SMOKE

if (-not $Force -and $isCi -and $runFlag -ne '1') {
    Write-Host '[SKIP] Hardware smoke requires host GPU/SYCL runtime and is disabled in standard CI.' -ForegroundColor Yellow
    Write-Host '[SKIP] Set AI_CLUSTER_RUN_HARDWARE_SMOKE=1 (or pass -Force locally) to run this suite.' -ForegroundColor Yellow
    exit 0
}

# The Ollama runtime check is the only hardware probe implemented; the llama.cpp
# SYCL path still has none.
$forward = @{}
foreach ($name in 'BaseUrl', 'Model', 'Runs', 'ContextTokens') {
    if ($PSBoundParameters.ContainsKey($name)) { $forward[$name] = $PSBoundParameters[$name] }
}
& (Join-Path $PSScriptRoot 'Test-OllamaRuntime.ps1') -Force @forward
exit $LASTEXITCODE
