function Invoke-SetupStarterPython {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/starters/setup-starter-python.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/starters/setup-starter-python.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER ProjectName
    Discovered from ProjectName.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter(Mandatory = $true)]
        [String] $ProjectName
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('ProjectName')) {
        $sourceParameters['ProjectName'] = $ProjectName
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\starters\setup-starter-python.ps1'
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
