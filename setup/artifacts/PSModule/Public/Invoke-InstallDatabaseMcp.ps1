function Invoke-InstallDatabaseMcp {
    <#
    .SYNOPSIS
    Runs the discovered PowerShell script 'scripts/workstation/install-database-mcp.ps1'.

    .DESCRIPTION
    Scaffolded from 'scripts/workstation/install-database-mcp.ps1'. Review its container invocation mappings before publishing.

    .PARAMETER Name
    Discovered from Name.

    .PARAMETER Command
    Discovered from Command.

    .PARAMETER ServerArgument
    Discovered from ServerArgument.

    .PARAMETER Client
    Discovered from Client.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [String] $Command,
        [Parameter()]
        [String[]] $ServerArgument,
        [Parameter()]
        [String] $Client
    )

    $sourceParameters = @{}
    if ($PSBoundParameters.ContainsKey('Name')) {
        $sourceParameters['Name'] = $Name
    }
    if ($PSBoundParameters.ContainsKey('Command')) {
        $sourceParameters['Command'] = $Command
    }
    if ($PSBoundParameters.ContainsKey('ServerArgument')) {
        $sourceParameters['ServerArgument'] = $ServerArgument
    }
    if ($PSBoundParameters.ContainsKey('Client')) {
        $sourceParameters['Client'] = $Client
    }
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $sourcePath = Join-Path $moduleRoot 'Scripts\workstation\install-database-mcp.ps1'
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
