function Invoke-SetupDocs {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/setup-docs.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/setup-docs.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER SourcePath
    Discovered from SourcePath.

    .PARAMETER TemplatePath
    Discovered from TemplatePath.

    .PARAMETER ReadmePath
    Discovered from ReadmePath.

    .PARAMETER OrganizationName
    Discovered from OrganizationName.

    .PARAMETER RepositoryName
    Discovered from RepositoryName.

    .PARAMETER SiteTitle
    Discovered from SiteTitle.

    .PARAMETER SiteUrl
    Discovered from SiteUrl.

    .PARAMETER BaseUrl
    Discovered from BaseUrl.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter()]
        [String] $SourcePath,
        [Parameter()]
        [String] $TemplatePath,
        [Parameter()]
        [String] $ReadmePath,
        [Parameter()]
        [String] $OrganizationName,
        [Parameter()]
        [String] $RepositoryName,
        [Parameter()]
        [String] $SiteTitle,
        [Parameter()]
        [String] $SiteUrl,
        [Parameter()]
        [String] $BaseUrl
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('SourcePath')) {
        $sourceParameters['SourcePath'] = $SourcePath
    }
    if ($PSBoundParameters.ContainsKey('TemplatePath')) {
        $sourceParameters['TemplatePath'] = $TemplatePath
    }
    if ($PSBoundParameters.ContainsKey('ReadmePath')) {
        $sourceParameters['ReadmePath'] = $ReadmePath
    }
    if ($PSBoundParameters.ContainsKey('OrganizationName')) {
        $sourceParameters['OrganizationName'] = $OrganizationName
    }
    if ($PSBoundParameters.ContainsKey('RepositoryName')) {
        $sourceParameters['RepositoryName'] = $RepositoryName
    }
    if ($PSBoundParameters.ContainsKey('SiteTitle')) {
        $sourceParameters['SiteTitle'] = $SiteTitle
    }
    if ($PSBoundParameters.ContainsKey('SiteUrl')) {
        $sourceParameters['SiteUrl'] = $SiteUrl
    }
    if ($PSBoundParameters.ContainsKey('BaseUrl')) {
        $sourceParameters['BaseUrl'] = $BaseUrl
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\setup-docs.ps1'
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
