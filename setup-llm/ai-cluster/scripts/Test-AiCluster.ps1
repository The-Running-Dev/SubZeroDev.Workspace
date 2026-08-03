[CmdletBinding()]
param(
    [string]$ComposeFile = (Join-Path $PSScriptRoot '../compose.yaml')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'Validating AI cluster skeleton files...' -ForegroundColor Cyan

$requiredPaths = @(
    (Join-Path $PSScriptRoot '../compose.yaml')
    (Join-Path $PSScriptRoot '../.env.example')
    (Join-Path $PSScriptRoot '../config/litellm.yaml')
    (Join-Path $PSScriptRoot '../config/model-manifest.example.yaml')
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $path"
    }
    Write-Host "[OK] $path" -ForegroundColor Green
}

if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warning 'Docker is not installed. Skipping docker compose validation.'
    return
}

$composeDirectory = Split-Path -Parent $ComposeFile
$envExample = Join-Path $composeDirectory '.env.example'
$envFile = Join-Path $composeDirectory '.env'

if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    Copy-Item -LiteralPath $envExample -Destination $envFile -Force
    Write-Host "Created temporary $envFile from .env.example for validation." -ForegroundColor Yellow
}

Push-Location $composeDirectory
try {
    docker compose --file $ComposeFile --profile headless config *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'docker compose config failed for headless profile.'
    }
    Write-Host '[OK] docker compose config succeeded (headless profile).' -ForegroundColor Green
}
finally {
    Pop-Location
}
