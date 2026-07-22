[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot 'docs'),
    [string]$TemplatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs-template'),
    [ValidateRange(1, 65535)][int]$Port = 3000,
    [string]$HostName = 'localhost',
    [switch]$NoOpen,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'modules/Common.ps1')

$resolvedTemplate = (Resolve-Path -LiteralPath $TemplatePath -ErrorAction Stop).Path
$resolvedSource = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$templatePackage = Join-Path $resolvedTemplate 'package.json'
$templateModules = Join-Path $resolvedTemplate 'node_modules'
$docsSetupScript = Join-Path $PSScriptRoot 'setup-docs.ps1'

if (-not (Test-Path -LiteralPath $templatePackage -PathType Leaf)) {
    throw "The Docusaurus submodule is not initialized at $resolvedTemplate. Run 'git submodule update --init --recursive' first."
}
if (-not (Test-Path -LiteralPath $docsSetupScript -PathType Leaf)) {
    throw "Documentation synchronization script is missing: $docsSetupScript"
}

Assert-CommandAvailable -Name 'node' -InstallHint 'Install Node.js 18 or later.'
Assert-CommandAvailable -Name 'npx' -InstallHint 'Install npm/npx with Node.js.'

if ($PSCmdlet.ShouldProcess($resolvedTemplate, 'Synchronize repository documentation')) {
    & $docsSetupScript -SourcePath $resolvedSource -TemplatePath $resolvedTemplate
}

if (-not $SkipInstall -and -not (Test-Path -LiteralPath $templateModules -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($resolvedTemplate, 'Install Docusaurus dependencies with pnpm 9')) {
        Push-Location $resolvedTemplate
        try {
            Invoke-NativeCommand -FilePath 'npx' -ArgumentList @(
                '-y', 'pnpm@9.0.0', 'install', '--frozen-lockfile'
            )
        }
        finally {
            Pop-Location
        }
    }
}
$startArguments = @(
    '--no-install', 'docusaurus', 'start',
    '--host', $HostName,
    '--port', $Port.ToString()
)
if ($NoOpen) { $startArguments += '--no-open' }

$localUrl = "http://$HostName`:$Port/"
Write-Host "Starting documentation at $localUrl" -ForegroundColor Green
Write-Host 'Press Ctrl+C to stop the development server.'

if ($PSCmdlet.ShouldProcess($resolvedTemplate, 'Start the Docusaurus development server')) {
    Push-Location $resolvedTemplate
    try {
        Invoke-NativeCommand -FilePath 'npx' -ArgumentList $startArguments
    }
    finally {
        Pop-Location
    }
}
