[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StatePath = (Join-Path $PSScriptRoot '../state'),
    [string]$LogsPath = (Join-Path $PSScriptRoot '../logs')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedState = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $StatePath -Force)).Path
$resolvedLogs = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $LogsPath -Force)).Path

Write-Host 'Issue #16 T3 skeleton: local inference lifecycle placeholder.' -ForegroundColor Yellow
Write-Host "State directory: $resolvedState"
Write-Host "Logs directory:  $resolvedLogs"
Write-Host 'T4 will add pinned llama-server process start/stop/health behavior.'

if ($PSCmdlet.ShouldProcess('local inference providers', 'Prepare skeleton state files')) {
    $stateFile = Join-Path $resolvedState 'providers.json'
    if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
        @{
            version = 1
            providers = @(
                @{ name = 'coding'; status = 'not-started'; endpoint = 'http://127.0.0.1:8081/v1' }
                @{ name = 'embeddings'; status = 'not-started'; endpoint = 'http://127.0.0.1:8082/v1' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateFile -Encoding UTF8
    }
}
