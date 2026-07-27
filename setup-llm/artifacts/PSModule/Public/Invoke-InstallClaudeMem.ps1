function Invoke-InstallClaudeMem {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/workstation/install-claude-mem.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/workstation/install-claude-mem.ps1'. Review its container invocation mappings before publishing.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param ()

    $sourceParameters = @{}
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\workstation\install-claude-mem.ps1'
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
