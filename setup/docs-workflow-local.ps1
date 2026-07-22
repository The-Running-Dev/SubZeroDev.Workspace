[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$WorkflowPath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.github/workflows/docs-pages.yml'),
    [string]$RunnerImage = 'catthehacker/ubuntu:act-latest',
    [switch]$ReuseRunnerImage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'modules/Common.ps1')

$repositoryRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot) -ErrorAction Stop).Path
$resolvedWorkflow = (Resolve-Path -LiteralPath $WorkflowPath -ErrorAction Stop).Path
$templatePackage = Join-Path $repositoryRoot 'docs-template/package.json'

Assert-CommandAvailable -Name 'act' -InstallHint 'Install nektos/act with the platform setup script, then rerun.'
Assert-CommandAvailable -Name 'docker' -InstallHint 'Install and start Docker Desktop or Docker Engine.'

$dockerServerVersion = & docker info --format '{{.ServerVersion}}' 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($dockerServerVersion | Out-String))) {
    throw 'Docker is installed, but its engine is not running. Start Docker Desktop or Docker Engine, then rerun.'
}
if (-not (Test-Path -LiteralPath $templatePackage -PathType Leaf)) {
    throw "The docs-template submodule is not initialized. Run 'git submodule update --init --recursive' first."
}

$actArguments = @(
    'pull_request',
    '--workflows', $resolvedWorkflow,
    '--job', 'build',
    '--platform', "ubuntu-latest=$RunnerImage"
)
if ($ReuseRunnerImage) { $actArguments += '--pull=false' }
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
    $actArguments += @('--container-architecture', 'linux/amd64')
}

if ($PSCmdlet.ShouldProcess($resolvedWorkflow, 'Run the documentation build job locally with act')) {
    Push-Location $repositoryRoot
    try {
        Invoke-NativeCommand -FilePath 'act' -ArgumentList $actArguments
    }
    finally {
        Pop-Location
    }
}
