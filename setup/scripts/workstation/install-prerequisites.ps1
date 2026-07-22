[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'ClaudeCode', 'Both')]
    [string]$Client = 'Both',

    [switch]$SkipGitHubCli
)

. (Join-Path $PSScriptRoot '..\..\modules\Common.ps1')

function Install-WingetCommand {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$DisplayName
    )

    Update-SessionPath
    if (Test-CommandAvailable -Name $Command) {
        Write-Success "$DisplayName is already installed."
        return
    }

    Assert-CommandAvailable -Name 'winget' -InstallHint "Install $DisplayName manually, then rerun the setup."
    if ($PSCmdlet.ShouldProcess($DisplayName, "Install Winget package $PackageId")) {
        Invoke-NativeCommand -FilePath 'winget' -ArgumentList @(
            'install', '--id', $PackageId, '--exact',
            '--accept-package-agreements', '--accept-source-agreements'
        )
        Update-SessionPath
        Assert-CommandAvailable -Name $Command -InstallHint "$DisplayName was installed, but '$Command' could not be found on PATH. Restart PowerShell and rerun the setup."
        Write-Success "$DisplayName was installed."
    }
}

Write-Step 'Installing command-line prerequisites'

# Node.js supplies npm/npx for claude-mem and the filesystem/Playwright MCP servers.
if (-not (Test-CommandAvailable -Name 'npm') -or -not (Test-CommandAvailable -Name 'npx')) {
    Install-WingetCommand -Command 'npm' -PackageId 'OpenJS.NodeJS.LTS' -DisplayName 'Node.js LTS'
}
else {
    Write-Success 'Node.js npm/npx is already installed.'
}

if ($Client -in @('Codex', 'Both')) {
    Install-WingetCommand -Command 'codex' -PackageId 'OpenAI.Codex' -DisplayName 'Codex CLI'
}

if ($Client -in @('ClaudeCode', 'Both')) {
    Install-WingetCommand -Command 'claude' -PackageId 'Anthropic.ClaudeCode' -DisplayName 'Claude Code'
}

if (-not $SkipGitHubCli) {
    Install-WingetCommand -Command 'gh' -PackageId 'GitHub.cli' -DisplayName 'GitHub CLI'
}

Write-Success 'Command-line prerequisites are available.'
