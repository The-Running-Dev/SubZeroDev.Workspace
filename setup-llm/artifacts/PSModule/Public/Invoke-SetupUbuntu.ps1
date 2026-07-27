function Invoke-SetupUbuntu {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/setup-ubuntu.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/setup-ubuntu.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER Client
    Discovered from Client.

    .PARAMETER SkipClaudeMem
    Discovered from SkipClaudeMem.

    .PARAMETER SkipGitHub
    Discovered from SkipGitHub.

    .PARAMETER SkipPlaywright
    Discovered from SkipPlaywright.

    .PARAMETER SkipGraphify
    Discovered from SkipGraphify.

    .PARAMETER IncludeFilesystem
    Discovered from IncludeFilesystem.

    .PARAMETER FilesystemPath
    Discovered from FilesystemPath.

    .PARAMETER IncludeDatabase
    Discovered from IncludeDatabase.

    .PARAMETER DatabaseName
    Discovered from DatabaseName.

    .PARAMETER DatabaseCommand
    Discovered from DatabaseCommand.

    .PARAMETER DatabaseArgument
    Discovered from DatabaseArgument.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter()]
        [String] $Client,
        [Parameter()]
        [switch] $SkipClaudeMem,
        [Parameter()]
        [switch] $SkipGitHub,
        [Parameter()]
        [switch] $SkipPlaywright,
        [Parameter()]
        [switch] $SkipGraphify,
        [Parameter()]
        [switch] $IncludeFilesystem,
        [Parameter()]
        [String[]] $FilesystemPath,
        [Parameter()]
        [switch] $IncludeDatabase,
        [Parameter()]
        [String] $DatabaseName,
        [Parameter()]
        [String] $DatabaseCommand,
        [Parameter()]
        [String[]] $DatabaseArgument
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('Client')) {
        $sourceParameters['Client'] = $Client
    }
    if ($PSBoundParameters.ContainsKey('SkipClaudeMem')) {
        $sourceParameters['SkipClaudeMem'] = $SkipClaudeMem
    }
    if ($PSBoundParameters.ContainsKey('SkipGitHub')) {
        $sourceParameters['SkipGitHub'] = $SkipGitHub
    }
    if ($PSBoundParameters.ContainsKey('SkipPlaywright')) {
        $sourceParameters['SkipPlaywright'] = $SkipPlaywright
    }
    if ($PSBoundParameters.ContainsKey('SkipGraphify')) {
        $sourceParameters['SkipGraphify'] = $SkipGraphify
    }
    if ($PSBoundParameters.ContainsKey('IncludeFilesystem')) {
        $sourceParameters['IncludeFilesystem'] = $IncludeFilesystem
    }
    if ($PSBoundParameters.ContainsKey('FilesystemPath')) {
        $sourceParameters['FilesystemPath'] = $FilesystemPath
    }
    if ($PSBoundParameters.ContainsKey('IncludeDatabase')) {
        $sourceParameters['IncludeDatabase'] = $IncludeDatabase
    }
    if ($PSBoundParameters.ContainsKey('DatabaseName')) {
        $sourceParameters['DatabaseName'] = $DatabaseName
    }
    if ($PSBoundParameters.ContainsKey('DatabaseCommand')) {
        $sourceParameters['DatabaseCommand'] = $DatabaseCommand
    }
    if ($PSBoundParameters.ContainsKey('DatabaseArgument')) {
        $sourceParameters['DatabaseArgument'] = $DatabaseArgument
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\setup-ubuntu.ps1'
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
