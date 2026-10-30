#Requires -Version 7.0
<#
.SYNOPSIS
Captures, reports or restores reviewed AI preferences in temporary profiles only.
.DESCRIPTION
Requires Python 3.11 through 3.14. All profiles, data and backups must be below
an existing SandboxRoot in the operating system temporary directory. No live
profile discovery, encryption, app setup, scheduling or Git operations occur.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('capture', 'status', 'restore')]
    [string]$Command,
    [Parameter(Mandatory)]
    [string]$SandboxRoot,
    [string]$ClaudeHome,
    [string]$CodexHome,
    [string]$DataPath,
    [string]$BackupRoot,
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'ai-settings.manifest.json'),
    [string]$PythonPath = 'python',
    [switch]$AsJson,
    [switch]$FailOnAttention,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$arguments = @('-I', (Join-Path $PSScriptRoot 'ai_settings.py'), $Command,
    '--sandbox-root', $SandboxRoot, '--manifest', $ManifestPath)
foreach ($entry in @(
    @('--claude-home', $ClaudeHome), @('--codex-home', $CodexHome),
    @('--data-path', $DataPath), @('--backup-root', $BackupRoot)
)) {
    if ($entry[1]) { $arguments += $entry }
}
if ($FailOnAttention) { $arguments += '--fail-on-attention' }
if ($Force) { $arguments += '--force' }
if ($WhatIfPreference) { $arguments += '--what-if' }

try {
    if ($Command -ne 'restore' -and $WhatIfPreference) {
        throw 'WhatIf is supported only for restore.'
    }
    if ($Command -eq 'restore' -and -not $WhatIfPreference -and
        -not $PSCmdlet.ShouldProcess('temporary fixture profiles', 'Restore reviewed preferences')) {
        if ($AsJson) { '{"changed":false,"items":[],"attention":[],"declined":true}' }
        exit 0
    }
    # Process names only: never inspect command lines or application profiles.
    if ($Command -eq 'restore') {
        $running = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -match '^codex(?:$|[-_])' })
        if ($running.Count -gt 0) { $arguments += '--codex-running' }
    }
    $output = & $PythonPath @arguments 2>$null
    $resultCode = $LASTEXITCODE
    $result = ($output -join "`n") | ConvertFrom-Json -AsHashtable
    if ($null -eq $result -or -not $result.ContainsKey('changed')) { throw 'Invalid engine result.' }
    if ($AsJson) {
        $output -join "`n"
    }
    else {
        'changed={0}; attention={1}; exit={2}' -f $result.changed, $result.attention.Count, $resultCode
        foreach ($item in $result.items) {
            '{0}: {1} {2}' -f $item.target, ($item.path -join '.'), $item.outcome
        }
        foreach ($item in $result.attention) { 'attention: {0} {1}' -f $item.target, $item.outcome }
        if ($result.error) { 'error: {0}' -f $result.error }
    }
    exit $resultCode
}
catch {
    # Do not emit exception messages, Python diagnostics or configuration content.
    if ($AsJson) { '{"changed":false,"items":[],"attention":[],"error":"entrypoint-failed"}' }
    else { 'error: entrypoint-failed' }
    exit 1
}
