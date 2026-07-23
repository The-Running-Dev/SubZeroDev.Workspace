function New-ProjectFile {
    <#
    .SYNOPSIS
    Runs the discovered module command 'New-ProjectFile'.

    .DESCRIPTION
    Scaffolded from 'scripts/Modules/Setup.psm1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER RelativePath
    Discovered from RelativePath.

    .PARAMETER Content
    Discovered from Content.

    .PARAMETER Force
    Discovered from Force.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter(Mandatory = $true)]
        [String] $RelativePath,
        [Parameter(Mandatory = $true)]
        [String] $Content,
        [Parameter()]
        [switch] $Force
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('RelativePath')) {
        $sourceParameters['RelativePath'] = $RelativePath
    }
    if ($PSBoundParameters.ContainsKey('Content')) {
        $sourceParameters['Content'] = $Content
    }
    if ($PSBoundParameters.ContainsKey('Force')) {
        $sourceParameters['Force'] = $Force
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\Modules\Setup.psm1'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new('Discovered PowerShell source was not found.', $sourcePath)
    }

    if (-not $PSCmdlet.ShouldProcess($sourcePath, 'Invoke discovered PowerShell ModuleFunction')) {
        return
    }

    Write-Verbose "Invoking discovered PowerShell source: $sourcePath"
    $sourceStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $sourceModule = Import-Module $sourcePath -Force -PassThru -ErrorAction Stop
    $sourceCommand = Get-Command -Module $sourceModule.Name -Name 'New-ProjectFile' -ErrorAction Stop
    & $sourceCommand @sourceParameters
    $sourceStopwatch.Stop()
    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)
}
