function New-ProjectStructure {
    <#
    .SYNOPSIS
    Runs the discovered module command 'New-ProjectStructure'.

    .DESCRIPTION
    Scaffolded from 'scripts/Modules/Setup.psm1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER Directories
    Discovered from Directories.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter()]
        [String[]] $Directories
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('Directories')) {
        $sourceParameters['Directories'] = $Directories
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
    $sourceCommand = Get-Command -Module $sourceModule.Name -Name 'New-ProjectStructure' -ErrorAction Stop
    & $sourceCommand @sourceParameters
    $sourceStopwatch.Stop()
    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)
}
