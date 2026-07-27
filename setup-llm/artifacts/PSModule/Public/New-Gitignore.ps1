function New-Gitignore {
    <#
    .SYNOPSIS
    Runs the discovered module command 'New-Gitignore'.

    .DESCRIPTION
    Scaffolded from 'scripts/Modules/Setup.psm1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER Language
    Discovered from Language.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter()]
        [String] $Language
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('Language')) {
        $sourceParameters['Language'] = $Language
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
    $sourceCommand = Get-Command -Module $sourceModule.Name -Name 'New-Gitignore' -ErrorAction Stop
    & $sourceCommand @sourceParameters
    $sourceStopwatch.Stop()
    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)
}
