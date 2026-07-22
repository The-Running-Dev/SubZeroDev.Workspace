[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Command,

    [Parameter()]
    [string[]]$ServerArgument = @(),

    [ValidateSet('Codex', 'ClaudeCode', 'Both')]
    [string]$Client = 'Both'
)

. (Join-Path $PSScriptRoot '../../modules/Common.ps1')

Write-Step 'Registering an explicitly selected database MCP server'
Assert-CommandAvailable -Name $Command -InstallHint 'Install and security-review the selected database MCP server before registering it.'

Write-WarningMessage 'Use a read-only database account, a development or sanitized database, statement timeouts, and row limits.'
Write-WarningMessage "This script does not store or inject a database connection string. Configure secrets through the selected server and client's secure mechanism."

if ($Client -in @('Codex', 'Both')) {
    Assert-CommandAvailable -Name 'codex' -InstallHint 'Install Codex or rerun with -Client ClaudeCode.'
    if (Test-McpServerRegistered -Client 'codex' -ServerName $Name) {
        Write-WarningMessage "$Name is already registered in Codex; leaving the existing configuration unchanged."
    }
    elseif ($PSCmdlet.ShouldProcess('Codex', "Register database MCP server '$Name'")) {
        Invoke-NativeCommand -FilePath 'codex' -ArgumentList (@('mcp', 'add', $Name, '--', $Command) + $ServerArgument)
    }
}

if ($Client -in @('ClaudeCode', 'Both')) {
    Assert-CommandAvailable -Name 'claude' -InstallHint 'Install Claude Code or rerun with -Client Codex.'
    if (Test-McpServerRegistered -Client 'claude' -ServerName $Name) {
        Write-WarningMessage "$Name is already registered in Claude Code; leaving the existing configuration unchanged."
    }
    elseif ($PSCmdlet.ShouldProcess('Claude Code', "Register database MCP server '$Name'")) {
        Invoke-NativeCommand -FilePath 'claude' -ArgumentList (@('mcp', 'add', '--scope', 'user', $Name, '--', $Command) + $ServerArgument)
    }
}

Write-Success "Database MCP server '$Name' registration finished."
