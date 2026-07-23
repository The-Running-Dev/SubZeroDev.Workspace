function Invoke-DocsWorkflowLocal {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/docs-workflow-local.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/docs-workflow-local.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER WorkflowPath
    Discovered from WorkflowPath.

    .PARAMETER RunnerImage
    Discovered from RunnerImage.

    .PARAMETER ReuseRunnerImage
    Discovered from ReuseRunnerImage.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter()]
        [String] $WorkflowPath,
        [Parameter()]
        [String] $RunnerImage,
        [Parameter()]
        [switch] $ReuseRunnerImage
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('WorkflowPath')) {
        $sourceParameters['WorkflowPath'] = $WorkflowPath
    }
    if ($PSBoundParameters.ContainsKey('RunnerImage')) {
        $sourceParameters['RunnerImage'] = $RunnerImage
    }
    if ($PSBoundParameters.ContainsKey('ReuseRunnerImage')) {
        $sourceParameters['ReuseRunnerImage'] = $ReuseRunnerImage
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\docs-workflow-local.ps1'
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
