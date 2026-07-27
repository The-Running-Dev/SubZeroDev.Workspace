function Invoke-SetupProject {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/setup-project.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/setup-project.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER ProjectName
    Discovered from ProjectName.

    .PARAMETER Language
    Discovered from Language.

    .PARAMETER Client
    Discovered from Client.

    .PARAMETER GitUserName
    Discovered from GitUserName.

    .PARAMETER GitUserEmail
    Discovered from GitUserEmail.

    .PARAMETER SkipGit
    Discovered from SkipGit.

    .PARAMETER SkipLanguageStarter
    Discovered from SkipLanguageStarter.

    .PARAMETER SkipValidation
    Discovered from SkipValidation.

    .PARAMETER AutoCommit
    Discovered from AutoCommit.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter(Mandatory = $true)]
        [String] $ProjectName,
        [Parameter(Mandatory = $true)]
        [String] $Language,
        [Parameter()]
        [String] $Client,
        [Parameter()]
        [String] $GitUserName,
        [Parameter()]
        [String] $GitUserEmail,
        [Parameter()]
        [switch] $SkipGit,
        [Parameter()]
        [switch] $SkipLanguageStarter,
        [Parameter()]
        [switch] $SkipValidation,
        [Parameter()]
        [switch] $AutoCommit
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('ProjectName')) {
        $sourceParameters['ProjectName'] = $ProjectName
    }
    if ($PSBoundParameters.ContainsKey('Language')) {
        $sourceParameters['Language'] = $Language
    }
    if ($PSBoundParameters.ContainsKey('Client')) {
        $sourceParameters['Client'] = $Client
    }
    if ($PSBoundParameters.ContainsKey('GitUserName')) {
        $sourceParameters['GitUserName'] = $GitUserName
    }
    if ($PSBoundParameters.ContainsKey('GitUserEmail')) {
        $sourceParameters['GitUserEmail'] = $GitUserEmail
    }
    if ($PSBoundParameters.ContainsKey('SkipGit')) {
        $sourceParameters['SkipGit'] = $SkipGit
    }
    if ($PSBoundParameters.ContainsKey('SkipLanguageStarter')) {
        $sourceParameters['SkipLanguageStarter'] = $SkipLanguageStarter
    }
    if ($PSBoundParameters.ContainsKey('SkipValidation')) {
        $sourceParameters['SkipValidation'] = $SkipValidation
    }
    if ($PSBoundParameters.ContainsKey('AutoCommit')) {
        $sourceParameters['AutoCommit'] = $AutoCommit
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\setup-project.ps1'
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
