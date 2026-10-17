#Requires -Version 5.1
<#
.SYNOPSIS
Setup module - shared helpers for the workstation and documentation setup scripts.

.DESCRIPTION
Console output, command discovery, PATH maintenance, native command execution,
MCP registration checks, and path resolution.

.NOTES
Project scaffolding moved to The-Running-Dev/SubZeroDev.GitHub (scripts/New-Project.ps1).
#>
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

function Test-IsWindowsPlatform {
    # $IsWindows does not exist on PowerShell 5.1, so the version test must stay first.
    return $PSVersionTable.PSVersion.Major -le 5 -or $IsWindows
}

function Get-PathComparer {
    if (Test-IsWindowsPlatform) { return [System.StringComparer]::OrdinalIgnoreCase }
    return [System.StringComparer]::Ordinal
}

function Update-SessionPath {
    $separator = [System.IO.Path]::PathSeparator
    $persistentPaths = if (Test-IsWindowsPlatform) {
        @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
            [Environment]::GetEnvironmentVariable('Path', 'User')
        )
    }
    else {
        @(
            (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/bin')
            '/opt/homebrew/bin'
            '/usr/local/bin'
            '/home/linuxbrew/.linuxbrew/bin'
        )
    }

    $seenPaths = [System.Collections.Generic.HashSet[string]]::new((Get-PathComparer))

    $mergedPaths = foreach ($source in @($persistentPaths) + @($env:PATH)) {
        foreach ($pathEntry in $source -split [regex]::Escape($separator)) {
            # Untrimmed entries would otherwise defeat deduplication and regrow PATH.
            $trimmedEntry = $pathEntry.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmedEntry) -and $seenPaths.Add($trimmedEntry)) {
                $trimmedEntry
            }
        }
    }

    $env:PATH = $mergedPaths -join $separator
}

function Add-DirectoryToSessionPath {
    param([Parameter(Mandatory)][string]$Directory)

    $separator = [System.IO.Path]::PathSeparator
    $comparer = Get-PathComparer
    $targetDirectory = $Directory.Trim()

    $remainingEntries = $env:PATH -split [regex]::Escape($separator) |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $comparer.Equals($_, $targetDirectory) }

    $env:PATH = (@($targetDirectory) + @($remainingEntries)) -join $separator
}

function Get-NpxCommand {
    if (Test-IsWindowsPlatform) {
        return @{ FilePath = 'cmd'; PrefixArguments = @('/c', 'npx') }
    }
    return @{ FilePath = 'npx'; PrefixArguments = @() }
}

function Get-NpmCommand {
    if (Test-IsWindowsPlatform) {
        $npmCommand = Get-Command 'npm.cmd' -ErrorAction Stop
        return @{ FilePath = $npmCommand.Source; PrefixArguments = @() }
    }
    return @{ FilePath = 'npm'; PrefixArguments = @() }
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

function Resolve-OrCreatePath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('Directory', 'File')][string]$PathKind
    )

    $expandedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $pathExists = Test-Path -LiteralPath $expandedPath
    if (-not $pathExists) {
        if ($PathKind -eq 'Directory') {
            New-Item -ItemType Directory -Path $expandedPath -Force | Out-Null
        }
        else {
            $parentPath = Split-Path -Parent $expandedPath
            if ($parentPath -and -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
                New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
            }
            New-Item -ItemType File -Path $expandedPath -Force | Out-Null
        }

        $pathExists = Test-Path -LiteralPath $expandedPath
        if (-not $pathExists -and $WhatIfPreference) {
            return $expandedPath
        }
    }

    switch ($PathKind) {
        'Directory' {
            if (-not (Test-Path -LiteralPath $expandedPath -PathType Container)) {
                throw "Expected a directory path but found a non-directory item: $expandedPath"
            }
        }
        'File' {
            if (-not (Test-Path -LiteralPath $expandedPath -PathType Leaf)) {
                throw "Expected a file path but found a non-file item: $expandedPath"
            }
        }
    }

    (Resolve-Path -LiteralPath $expandedPath -ErrorAction Stop).Path
}

Export-ModuleMember -Function @(
    'Write-Step'
    'Write-Success'
    'Write-WarningMessage'
    'Test-CommandAvailable'
    'Test-IsWindowsPlatform'
    'Get-PathComparer'
    'Update-SessionPath'
    'Add-DirectoryToSessionPath'
    'Get-NpmCommand'
    'Get-NpxCommand'
    'Assert-CommandAvailable'
    'Invoke-NativeCommand'
    'Test-McpServerRegistered'
    'Resolve-OrCreatePath'
)
