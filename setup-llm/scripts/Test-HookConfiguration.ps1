#Requires -Version 7.4
<#
.SYNOPSIS
Inventory supported command-hook registrations in explicitly selected local JSON/JSONC files.
.DESCRIPTION
Read-only, redacted static audit. Does not run hooks, resolve commands or evaluate host loading,
trust, matchers, permissions or latency. See docs/security/hook-configuration-audit.md.
Exit codes: 0 = supported, no duplicates; 1 = duplicates or unverified input; 2 = invocation error.
.PARAMETER LiteralPath
Explicit local JSON/JSONC settings or hook files, in the desired report order.
.PARAMETER HostKind
Claude or Codex. All selected files belong to this host; no format guessing occurs.
.PARAMETER AsJson
Emit only the versioned JSON report.
.EXAMPLE
./Test-HookConfiguration.ps1 -HostKind Claude -LiteralPath ./settings.json -AsJson
#>
[CmdletBinding()]
param([string[]]$LiteralPath = @(), [string]$HostKind = '', [switch]$AsJson)
$ErrorActionPreference = 'Stop'
if (!$LiteralPath.Count -or $LiteralPath.Count -gt 64 -or $HostKind -notin @('Claude', 'Codex')) {
    if ($AsJson) { '{"schemaVersion":1,"classification":"unverified","reasonCode":"invalid-invocation","configurations":[],"duplicates":[]}' }
    else { 'Hook audit: invalid-invocation. Supply HostKind Claude/Codex and 1-64 explicit local JSON/JSONC paths.' }
    exit 2
}
Import-Module (Join-Path $PSScriptRoot 'modules/HookConfigurationAudit.psm1') -Force
$report = Invoke-HookConfigurationAudit -LiteralPath $LiteralPath -HostKind $HostKind
if ($AsJson) { $report | ConvertTo-Json -Depth 16 }
else {
    "Hook audit: $($report.classification) ($($report.hostKind), selected registrations only)."
    foreach ($configuration in $report.configurations) {
        "Input $($configuration.input): $($configuration.classification) [$($configuration.reasonCode)]"
        foreach ($registration in $configuration.registrations) {
            "  $($registration.event) group $($registration.group) hook $($registration.hook): $($registration.classification) [$($registration.reasonCode)]"
        }
    }
    foreach ($duplicate in $report.duplicates) {
        "Identical registration $($duplicate.id) present at:"
        foreach ($member in $duplicate.members) { "  input $($member.input), $($member.event), group $($member.group), hook $($member.hook)" }
    }
    'Host loading, override rules and execution are not evaluated. Identical presence does not prove double execution.'
}
if ($report.classification -eq 'supported' -and !$report.duplicates.Count) { exit 0 }
exit 1
