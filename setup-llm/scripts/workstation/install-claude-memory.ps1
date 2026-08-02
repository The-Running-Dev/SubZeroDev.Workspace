[CmdletBinding(SupportsShouldProcess)]
param()
$modulePath = Join-Path $PSScriptRoot '../modules/Setup.psm1'
Import-Module $modulePath -Force

function Get-ClaudeCodeVersionInfo {
    param([string]$CommandPath)

    if ([string]::IsNullOrWhiteSpace($CommandPath)) {
        $CommandPath = (Get-Command 'claude' -ErrorAction Stop).Source
    }

    $output = & $CommandPath --version 2>&1 | Out-String
    $versionMatch = [regex]::Match($output, '(\d+)\.(\d+)\.(\d+)')

    [pscustomobject]@{
        CommandPath = $CommandPath
        Output = $output.Trim()
        Version = if ($versionMatch.Success) { [version]$versionMatch.Value } else { $null }
    }
}

function Get-ClaudeCodeVersionCandidate {
    $comparison = if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
        [System.StringComparer]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparer]::Ordinal
    }
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new($comparison)

    foreach ($command in Get-Command 'claude' -All -ErrorAction SilentlyContinue) {
        if (($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) -and
            [string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($command.Source))) {
            continue
        }
        if (-not $seenPaths.Add($command.Source)) { continue }

        try {
            $candidate = Get-ClaudeCodeVersionInfo -CommandPath $command.Source
            if ($null -ne $candidate.Version) { $candidate }
        }
        catch {
            Write-WarningMessage "Could not inspect Claude Code candidate '$($command.Source)': $_"
        }
    }
}

function Select-ClaudeCodeCommand {
    param([Parameter(Mandatory)][string]$CommandPath)

    $commandDirectory = Split-Path -Parent $CommandPath
    $separator = [System.IO.Path]::PathSeparator
    $env:PATH = "$commandDirectory$separator$env:PATH"
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
        $newerCandidate = Get-ClaudeCodeVersionCandidate |
            Where-Object { $_.Version -ge $minimumVersion } |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1

        if ($null -ne $newerCandidate -and $newerCandidate.CommandPath -ne $versionInfo.CommandPath) {
            $updateDescription = "Use newer installed Claude Code $($newerCandidate.Version)"
            if (-not $PSCmdlet.ShouldProcess($newerCandidate.CommandPath, $updateDescription)) {
                Write-WarningMessage 'The newer Claude Code installation was not selected, so built-in auto-memory cannot be verified.'
                return
            }

            Select-ClaudeCodeCommand -CommandPath $newerCandidate.CommandPath
            $versionInfo = $newerCandidate
            Write-Host $versionInfo.Output
        }
        else {
            $usesGlobalNpm = Test-GlobalNpmCommand -CommandPath $versionInfo.CommandPath
            $updateDescription = if ($usesGlobalNpm) {
                'Install the latest native Claude Code build from the resolved npm launcher'
            }
            else {
                'Run the Claude Code installer-aware updater'
            }

            if (-not $PSCmdlet.ShouldProcess($versionInfo.CommandPath, $updateDescription)) {
                Write-WarningMessage 'Claude Code was not updated, so built-in auto-memory cannot be verified.'
                return
            }

            if ($usesGlobalNpm) {
                # Migrate away from the legacy npm installation. This avoids npm's
                # Windows post-install child shell, which may fail to resolve node
                # even though npm itself was launched by node.exe.
                Invoke-NativeCommand -FilePath $versionInfo.CommandPath -ArgumentList @('install', 'latest')
            }
            else {
                Invoke-NativeCommand -FilePath $versionInfo.CommandPath -ArgumentList @('update')
            }

            Update-SessionPath
            $versionInfo = Get-ClaudeCodeVersionCandidate |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
            if ($null -ne $versionInfo) {
                Select-ClaudeCodeCommand -CommandPath $versionInfo.CommandPath
            }
            else {
                $versionInfo = Get-ClaudeCodeVersionInfo
            }
            Write-Host $versionInfo.Output

            if ($null -eq $versionInfo.Version) {
                throw "Claude Code was updated, but its version could not be parsed from '$($versionInfo.Output)'."
            }
            if ($versionInfo.Version -lt $minimumVersion) {
                throw "Claude Code still resolves to $($versionInfo.Version) at '$($versionInfo.CommandPath)' after updating. Remove or update the older installation that appears first on PATH."
            }
        }
    }

    Write-Success "Claude Code $($versionInfo.Version) supports built-in auto-memory."
}

Write-Host 'Inside each repository, run /init once to create project instructions.'
Write-Host 'Use /memory to inspect or toggle auto-memory and /context to verify what loaded.'
