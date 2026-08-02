[CmdletBinding(SupportsShouldProcess)]
param()
$modulePath = Join-Path $PSScriptRoot '../modules/Setup.psm1'
Import-Module $modulePath -Force

function Get-ClaudeCodeVersionInfo {
    $command = Get-Command 'claude' -ErrorAction Stop
    $output = & $command.Source --version 2>&1 | Out-String
    $versionMatch = [regex]::Match($output, '(\d+)\.(\d+)\.(\d+)')

    [pscustomobject]@{
        CommandPath = $command.Source
        Output = $output.Trim()
        Version = if ($versionMatch.Success) { [version]$versionMatch.Value } else { $null }
    }
}

function Test-GlobalNpmCommand {
    param([Parameter(Mandatory)][string]$CommandPath)

    if (-not (Test-CommandAvailable -Name 'npm')) { return $false }

    $npmPrefixOutput = & npm prefix --global 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($npmPrefixOutput)) { return $false }

    $npmPrefix = [System.IO.Path]::GetFullPath($npmPrefixOutput.Trim())
    $commandDirectory = [System.IO.Path]::GetFullPath((Split-Path -Parent $CommandPath))
    $candidateDirectories = @($npmPrefix, (Join-Path $npmPrefix 'bin'))
    $comparison = if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }

    foreach ($candidateDirectory in $candidateDirectories) {
        $candidatePath = [System.IO.Path]::GetFullPath($candidateDirectory)
        if ([string]::Equals($commandDirectory, $candidatePath, $comparison)) { return $true }
    }

    return $false
}

function Add-NodeDirectoryToPath {
    $nodeCommand = Get-Command 'node' -ErrorAction SilentlyContinue
    if ($null -eq $nodeCommand) {
        throw "The resolved npm installation requires Node.js, but 'node' is not available on PATH. Install Node.js and rerun setup."
    }

    $nodeDirectory = Split-Path -Parent $nodeCommand.Source
    $separator = [System.IO.Path]::PathSeparator
    $env:PATH = "$nodeDirectory$separator$env:PATH"
}

Write-Step 'Checking Claude Code built-in memory'
Assert-CommandAvailable -Name 'claude' -InstallHint "Install or update Claude Code using Anthropic's current official installer, then rerun."

$minimumVersion = [version]'2.1.59'
$versionInfo = Get-ClaudeCodeVersionInfo
Write-Host $versionInfo.Output

if ($null -eq $versionInfo.Version) {
    Write-WarningMessage "Could not parse the Claude Code version. Built-in auto-memory requires version $minimumVersion or later."
}
else {
    if ($versionInfo.Version -lt $minimumVersion) {
        Write-WarningMessage "Claude Code $($versionInfo.Version) is older than the required version $minimumVersion."

        Update-SessionPath
        $usesGlobalNpm = Test-GlobalNpmCommand -CommandPath $versionInfo.CommandPath
        $updateDescription = if ($usesGlobalNpm) {
            'Update the resolved global npm package to the latest version'
        }
        else {
            'Run the Claude Code installer-aware updater'
        }

        if (-not $PSCmdlet.ShouldProcess($versionInfo.CommandPath, $updateDescription)) {
            Write-WarningMessage 'Claude Code was not updated, so built-in auto-memory cannot be verified.'
            return
        }

        if ($usesGlobalNpm) {
            # npm lifecycle scripts invoke `node` by name in a child shell. Put
            # the resolved runtime first even when npm itself can find an
            # adjacent node.exe without relying on PATH.
            Add-NodeDirectoryToPath
            Invoke-NativeCommand -FilePath 'npm' -ArgumentList @('install', '--global', '@anthropic-ai/claude-code@latest')
        }
        else {
            Invoke-NativeCommand -FilePath $versionInfo.CommandPath -ArgumentList @('update')
        }

        Update-SessionPath
        $versionInfo = Get-ClaudeCodeVersionInfo
        Write-Host $versionInfo.Output

        if ($null -eq $versionInfo.Version) {
            throw "Claude Code was updated, but its version could not be parsed from '$($versionInfo.Output)'."
        }
        if ($versionInfo.Version -lt $minimumVersion) {
            throw "Claude Code still resolves to $($versionInfo.Version) at '$($versionInfo.CommandPath)' after updating. Remove or update the older installation that appears first on PATH."
        }
    }

    Write-Success "Claude Code $($versionInfo.Version) supports built-in auto-memory."
}

Write-Host 'Inside each repository, run /init once to create project instructions.'
Write-Host 'Use /memory to inspect or toggle auto-memory and /context to verify what loaded.'
