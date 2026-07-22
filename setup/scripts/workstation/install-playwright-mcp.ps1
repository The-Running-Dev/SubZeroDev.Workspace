[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'ClaudeCode', 'Both')]
    [string]$Client = 'Both'
)

. (Join-Path $PSScriptRoot '../../modules/Common.ps1')

Write-Step 'Registering Microsoft Playwright MCP'
Assert-CommandAvailable -Name 'npx' -InstallHint 'Install the current Node.js LTS release first.'

$npxCommand = Get-NpxCommand
$serverArguments = $npxCommand.PrefixArguments + @('-y', '@playwright/mcp@latest', '--isolated')

if ($Client -in @('Codex', 'Both')) {
    Assert-CommandAvailable -Name 'codex' -InstallHint 'Install Codex or rerun with -Client ClaudeCode.'
    if (Test-McpServerRegistered -Client 'codex' -ServerName 'playwright') {
        Write-WarningMessage 'Playwright MCP is already registered in Codex; leaving the existing configuration unchanged.'
    }
    elseif ($PSCmdlet.ShouldProcess('Codex', 'Register Playwright MCP server')) {
        Invoke-NativeCommand -FilePath 'codex' -ArgumentList (@('mcp', 'add', 'playwright', '--', $npxCommand.FilePath) + $serverArguments)
    }
}

if ($Client -in @('ClaudeCode', 'Both')) {
    Assert-CommandAvailable -Name 'claude' -InstallHint 'Install Claude Code or rerun with -Client Codex.'
    if (Test-McpServerRegistered -Client 'claude' -ServerName 'playwright') {
        Write-WarningMessage 'Playwright MCP is already registered in Claude Code; leaving the existing configuration unchanged.'
    }
    elseif ($PSCmdlet.ShouldProcess('Claude Code', 'Register Playwright MCP server')) {
        Invoke-NativeCommand -FilePath 'claude' -ArgumentList (@('mcp', 'add', '--scope', 'user', 'playwright', '--', $npxCommand.FilePath) + $serverArguments)
    }
}

Write-Success 'Playwright MCP registration finished with an isolated browser profile.'
