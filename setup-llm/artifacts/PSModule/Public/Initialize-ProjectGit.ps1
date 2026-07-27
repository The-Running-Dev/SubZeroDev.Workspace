function Initialize-ProjectGit {
    <#
    .SYNOPSIS
    Runs the discovered module command 'Initialize-ProjectGit'.

    .DESCRIPTION
    Scaffolded from 'scripts/Modules/Setup.psm1'. Review its container invocation mappings before publishing.

    .PARAMETER ProjectPath
    Discovered from ProjectPath.

    .PARAMETER UserName
    Discovered from UserName.

    .PARAMETER UserEmail
    Discovered from UserEmail.

    .PARAMETER SkipInit
    Discovered from SkipInit.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProjectPath,
        [Parameter()]
        [String] $UserName,
        [Parameter()]
        [String] $UserEmail,
        [Parameter()]
        [switch] $SkipInit
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('ProjectPath')) {
        $sourceParameters['ProjectPath'] = $ProjectPath
    }
    if ($PSBoundParameters.ContainsKey('UserName')) {
        $sourceParameters['UserName'] = $UserName
    }
    if ($PSBoundParameters.ContainsKey('UserEmail')) {
        $sourceParameters['UserEmail'] = $UserEmail
    }
    if ($PSBoundParameters.ContainsKey('SkipInit')) {
        $sourceParameters['SkipInit'] = $SkipInit
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
    $sourceCommand = Get-Command -Module $sourceModule.Name -Name 'Initialize-ProjectGit' -ErrorAction Stop
    & $sourceCommand @sourceParameters
    $sourceStopwatch.Stop()
    Write-Verbose ("PowerShell source finished after {0:N2}s." -f $sourceStopwatch.Elapsed.TotalSeconds)
}
