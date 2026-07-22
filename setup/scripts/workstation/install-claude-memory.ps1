[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot '..\..\modules\Common.ps1')

Write-Step 'Checking Claude Code built-in memory'
Assert-CommandAvailable -Name 'claude' -InstallHint "Install or update Claude Code using Anthropic's current official installer, then rerun."

$versionOutput = & claude --version 2>&1 | Out-String
Write-Host $versionOutput.Trim()

$versionMatch = [regex]::Match($versionOutput, '(\d+)\.(\d+)\.(\d+)')
if (-not $versionMatch.Success) {
    Write-WarningMessage 'Could not parse the Claude Code version. Built-in auto-memory requires version 2.1.59 or later.'
}
else {
    $installedVersion = [version]$versionMatch.Value
    if ($installedVersion -lt [version]'2.1.59') {
        throw "Claude Code $installedVersion is installed. Update to 2.1.59 or later for built-in auto-memory."
    }
    Write-Success "Claude Code $installedVersion supports built-in auto-memory."
}

Write-Host 'Inside each repository, run /init once to create project instructions.'
Write-Host 'Use /memory to inspect or toggle auto-memory and /context to verify what loaded.'
