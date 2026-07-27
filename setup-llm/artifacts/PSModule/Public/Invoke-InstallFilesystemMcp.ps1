function Invoke-InstallFilesystemMcp {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/workstation/install-filesystem-mcp.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/workstation/install-filesystem-mcp.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER AllowedPath
    Discovered from AllowedPath.

    .PARAMETER Client
    Discovered from Client.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String[]] $AllowedPath,
        [Parameter()]
        [String] $Client
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('AllowedPath')) {
        $sourceParameters['AllowedPath'] = $AllowedPath
    }
    if ($PSBoundParameters.ContainsKey('Client')) {
        $sourceParameters['Client'] = $Client
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\workstation\install-filesystem-mcp.ps1'
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
