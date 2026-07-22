[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Codex', 'ClaudeCode', 'Both')][string]$Client = 'Both',
    [switch]$SkipClaudeMem, [switch]$SkipGitHub, [switch]$SkipPlaywright, [switch]$SkipGraphify,
    [switch]$IncludeFilesystem, [string[]]$FilesystemPath = @(),
    [switch]$IncludeDatabase, [string]$DatabaseName, [string]$DatabaseCommand,
    [string[]]$DatabaseArgument = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'modules/Common.ps1')

if (-not $IsLinux) { throw 'setup-ubuntu.ps1 can only run on Linux.' }
Assert-CommandAvailable 'apt-get' 'This setup supports Ubuntu and Debian-derived distributions with apt-get.'
Assert-CommandAvailable 'sudo' 'Install sudo or run the prerequisite package commands as root.'

$script:AptPackageIndexUpdated = $false

function Update-AptPackageIndex {
    if ($script:AptPackageIndexUpdated) { return }
    Invoke-NativeCommand 'sudo' @('apt-get', 'update')
    $script:AptPackageIndexUpdated = $true
}

function Install-AptCommand {
    param([string]$Command, [string[]]$Package, [string]$DisplayName)
    Update-SessionPath
    if (Test-CommandAvailable $Command) { Write-Success "$DisplayName is already installed."; return }
    if ($PSCmdlet.ShouldProcess($DisplayName, "Install apt package(s): $($Package -join ', ')")) {
        Update-AptPackageIndex
        Invoke-NativeCommand 'sudo' (@('apt-get', 'install', '--yes') + $Package)
        Update-SessionPath
        Assert-CommandAvailable $Command "$DisplayName was installed, but '$Command' is not on PATH. Start a new shell and rerun."
    }
}

function Install-NpmCommand {
    param([string]$Command, [string]$Package, [string]$DisplayName)
    if (Test-CommandAvailable $Command) { Write-Success "$DisplayName is already installed."; return }
    if ($PSCmdlet.ShouldProcess($DisplayName, "Install npm package $Package globally")) {
        Invoke-NativeCommand 'npm' @('install', '--global', $Package)
        Update-SessionPath
        Assert-CommandAvailable $Command "$DisplayName was installed, but '$Command' is not on PATH. Configure npm's user prefix and rerun without sudo."
    }
}

Write-Step 'Installing Ubuntu prerequisites with apt, pipx, and npm'
if (-not (Test-CommandAvailable 'npm') -or -not (Test-CommandAvailable 'npx')) { Install-AptCommand 'npm' @('nodejs', 'npm') 'Node.js and npm' }
if (-not $SkipGitHub) { Install-AptCommand 'gh' @('gh') 'GitHub CLI' }
if (-not $SkipGraphify -and -not (Test-CommandAvailable 'uv')) {
    Install-AptCommand 'pipx' @('pipx') 'pipx'
    if ($PSCmdlet.ShouldProcess('Astral uv', 'Install with pipx')) { Invoke-NativeCommand 'pipx' @('install', 'uv'); Update-SessionPath }
}
if ($Client -in @('Codex', 'Both')) { Install-NpmCommand 'codex' '@openai/codex' 'Codex CLI' }
if ($Client -in @('ClaudeCode', 'Both')) { Install-NpmCommand 'claude' '@anthropic-ai/claude-code' 'Claude Code' }

if ($WhatIfPreference) {
    Write-WarningMessage 'Platform prerequisite preview complete. Shared integrations were not run because preview mode does not install missing commands.'
    return
}

$parameters = @{} + $PSBoundParameters
& (Join-Path $PSScriptRoot 'setup-workstation.ps1') @parameters
