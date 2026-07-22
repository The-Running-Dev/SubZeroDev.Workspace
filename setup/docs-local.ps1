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
Assert-CommandAvailable -Name 'git' -InstallHint 'Install Git to create the isolated local documentation workspace.'

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
if (-not (Test-Path -LiteralPath $templateModules -PathType Container)) {
    throw "Docusaurus dependencies are missing from $resolvedTemplate. Rerun without -SkipInstall."
}

if ($WhatIfPreference) {
    & $docsSetupScript -SourcePath $resolvedSource -TemplatePath $resolvedTemplate -WhatIf
    Write-Host 'Local documentation preview completed.' -ForegroundColor Yellow
    return
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

$stagingTemplate = Join-Path ([System.IO.Path]::GetTempPath()) "llms-docs-local-$PID"
if (Test-Path -LiteralPath $stagingTemplate) {
    throw "The temporary documentation workspace already exists: $stagingTemplate"
}

if ($PSCmdlet.ShouldProcess($stagingTemplate, 'Create an isolated local documentation workspace')) {
    Invoke-NativeCommand -FilePath 'git' -ArgumentList @(
        'clone', '--quiet', '--local', '--no-hardlinks', $resolvedTemplate, $stagingTemplate
    )

    $stagingModules = Join-Path $stagingTemplate 'node_modules'
    $linkType = if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $stagingModules -Target $templateModules | Out-Null
    & $docsSetupScript -SourcePath $resolvedSource -TemplatePath $stagingTemplate
}

if ($PSCmdlet.ShouldProcess($stagingTemplate, 'Start the Docusaurus development server')) {
    $previousDocsSourcePath = [Environment]::GetEnvironmentVariable('LLMS_DOCS_SOURCE_PATH', 'Process')
    [Environment]::SetEnvironmentVariable('LLMS_DOCS_SOURCE_PATH', $resolvedSource, 'Process')
    Push-Location $stagingTemplate
    try {
        Invoke-NativeCommand -FilePath 'npx' -ArgumentList $startArguments
    }
    finally {
        Pop-Location
        [Environment]::SetEnvironmentVariable('LLMS_DOCS_SOURCE_PATH', $previousDocsSourcePath, 'Process')
        $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $resolvedStaging = [System.IO.Path]::GetFullPath($stagingTemplate)
        if ($resolvedStaging.StartsWith($temporaryRoot) -and (Split-Path -Leaf $resolvedStaging) -like 'llms-docs-local-*') {
            Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
        }
    }
}
