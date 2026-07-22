[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]]$AllowedPath,

    [ValidateSet('Codex', 'ClaudeCode', 'Both')]
    [string]$Client = 'Both'
)

. (Join-Path $PSScriptRoot '../../modules/Common.ps1')

Write-Step 'Registering the optional Filesystem MCP server'
Assert-CommandAvailable -Name 'npx' -InstallHint 'Install the current Node.js LTS release first.'

$resolvedPaths = foreach ($pathItem in $AllowedPath) {
    if (-not (Test-Path -LiteralPath $pathItem -PathType Container)) {
        throw "Allowed path does not exist or is not a directory: $pathItem"
    }
    $resolved = (Resolve-Path -LiteralPath $pathItem).Path
    if ([System.IO.Path]::GetPathRoot($resolved) -eq $resolved) {
        throw "Refusing to grant a filesystem root: $resolved"
    }
    $resolved
}

Write-WarningMessage "The filesystem MCP server can read and write within: $($resolvedPaths -join ', ')"
$npxCommand = Get-NpxCommand
$serverArguments = $npxCommand.PrefixArguments + @('-y', '@modelcontextprotocol/server-filesystem') + $resolvedPaths

if ($Client -in @('Codex', 'Both')) {
    Assert-CommandAvailable -Name 'codex' -InstallHint 'Install Codex or rerun with -Client ClaudeCode.'
    if (Test-McpServerRegistered -Client 'codex' -ServerName 'filesystem') {
        Write-WarningMessage 'Filesystem MCP is already registered in Codex; leaving the existing configuration unchanged.'
    }
    elseif ($PSCmdlet.ShouldProcess('Codex', 'Register restricted Filesystem MCP server')) {
        Invoke-NativeCommand -FilePath 'codex' -ArgumentList (@('mcp', 'add', 'filesystem', '--', $npxCommand.FilePath) + $serverArguments)
    }
}

if ($Client -in @('ClaudeCode', 'Both')) {
    Assert-CommandAvailable -Name 'claude' -InstallHint 'Install Claude Code or rerun with -Client Codex.'
    if (Test-McpServerRegistered -Client 'claude' -ServerName 'filesystem') {
        Write-WarningMessage 'Filesystem MCP is already registered in Claude Code; leaving the existing configuration unchanged.'
    }
    elseif ($PSCmdlet.ShouldProcess('Claude Code', 'Register restricted Filesystem MCP server')) {
        Invoke-NativeCommand -FilePath 'claude' -ArgumentList (@('mcp', 'add', '--scope', 'user', 'filesystem', '--', $npxCommand.FilePath) + $serverArguments)
    }
}

Write-Success 'Filesystem MCP registration finished.'
