function Invoke-DocsLocal {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/docs-local.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/docs-local.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER SourcePath
    Discovered from SourcePath.

    .PARAMETER TemplatePath
    Discovered from TemplatePath.

    .PARAMETER Port
    Discovered from Port.

    .PARAMETER HostName
    Discovered from HostName.

    .PARAMETER NoOpen
    Discovered from NoOpen.

    .PARAMETER SkipInstall
    Discovered from SkipInstall.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter()]
        [String] $SourcePath,
        [Parameter()]
        [String] $TemplatePath,
        [Parameter()]
        [Int32] $Port,
        [Parameter()]
        [String] $HostName,
        [Parameter()]
        [switch] $NoOpen,
        [Parameter()]
        [switch] $SkipInstall
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('SourcePath')) {
        $sourceParameters['SourcePath'] = $SourcePath
    }
    if ($PSBoundParameters.ContainsKey('TemplatePath')) {
        $sourceParameters['TemplatePath'] = $TemplatePath
    }
    if ($PSBoundParameters.ContainsKey('Port')) {
        $sourceParameters['Port'] = $Port
    }
    if ($PSBoundParameters.ContainsKey('HostName')) {
        $sourceParameters['HostName'] = $HostName
    }
    if ($PSBoundParameters.ContainsKey('NoOpen')) {
        $sourceParameters['NoOpen'] = $NoOpen
    }
    if ($PSBoundParameters.ContainsKey('SkipInstall')) {
        $sourceParameters['SkipInstall'] = $SkipInstall
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\docs-local.ps1'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Discovered PowerShell source was not found.', $sourcePath)
    }

    if (-not $PSCmdlet.ShouldProcess($sourcePath, 'Invoke discovered PowerShell Script')) {
        return
    }

    Write-Verbose "Invoking discovered PowerShell source: $sourcePath"
    $sourceStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    & $sourcePath @sourceParameters
    $sourceStopwatch.Stop()
    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)
}
