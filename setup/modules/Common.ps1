Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
    $separator = [System.IO.Path]::PathSeparator
    $persistentPaths = if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
        @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
            [Environment]::GetEnvironmentVariable('Path', 'User')
        ) -join $separator
    }
    else {
        @(
            (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/bin')
            '/opt/homebrew/bin'
            '/usr/local/bin'
            '/home/linuxbrew/.linuxbrew/bin'
        ) -join $separator
    }

    # Preserve process-only entries while making newly installed commands
    # available without requiring the user to restart PowerShell.
    $env:PATH = "$persistentPaths$separator$env:PATH"
}

function Get-NpxCommand {
    if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
        return @{ FilePath = 'cmd'; PrefixArguments = @('/c', 'npx') }
    }
    return @{ FilePath = 'npx'; PrefixArguments = @() }
}

function Assert-CommandAvailable {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$InstallHint
    )
    if (-not (Test-CommandAvailable -Name $Name)) {
        throw "'$Name' was not found. $InstallHint"
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter()][string[]]$ArgumentList = @()
    )
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
    }
}

function Test-McpServerRegistered {
    param(
        [Parameter(Mandatory)][ValidateSet('codex', 'claude')][string]$Client,
        [Parameter(Mandatory)][string]$ServerName
    )
    if (-not (Test-CommandAvailable -Name $Client)) { return $false }
    $output = & $Client mcp list 2>&1 | Out-String
    return $output -match "(?im)\b$([regex]::Escape($ServerName))\b"
}
