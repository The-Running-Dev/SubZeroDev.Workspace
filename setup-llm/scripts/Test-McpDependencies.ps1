#Requires -Version 7.4
<#
.SYNOPSIS
Statically audit direct MCP launch dependency selectors in explicit local JSON/JSONC files.
.DESCRIPTION
Reads mcpServers objects as data. Never runs discovered commands, fetches URLs, resolves
packages, installs tools or changes registration. See docs/security/mcp-dependency-audit.md.
Exit codes: 0 = all direct selectors exact; 1 = mutable/unverified; 2 = invocation error.
An exact direct pin proves neither trusted provenance nor transitive reproducibility.
.PARAMETER LiteralPath
One or more local UTF-8 .json/.jsonc files containing an mcpServers object.
.PARAMETER AsJson
Write only the versioned JSON report to the success stream.
.EXAMPLE
./Test-McpDependencies.ps1 -LiteralPath ./.mcp.json -AsJson
#>
[CmdletBinding()]
param(
    [string[]]$LiteralPath = @(),
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'modules/McpDependencyAudit.psm1') -Force
if (!$LiteralPath.Count) {
    if ($AsJson) { '{"schemaVersion":1,"classification":"unverified","reasonCode":"missing-input","configurations":[]}' }
    else { 'MCP audit: unverified (missing-input). Supply explicit local JSON/JSONC files.' }
    exit 2
}
$report = Invoke-McpDependencyAudit -LiteralPath $LiteralPath
if ($AsJson) { $report | ConvertTo-Json -Depth 16 }
else {
    "MCP audit: $($report.classification) (direct launch selectors only)."
    foreach ($configuration in $report.configurations) {
        "Input $($configuration.input): $($configuration.classification) [$($configuration.reasonCode)]"
        foreach ($server in $configuration.servers) {
            "  $($server.server): $($server.launchType) / $($server.classification)"
            foreach ($dependency in $server.dependencies) {
                "    $($dependency.selector) [$($dependency.reasonCode)]"
            }
            if ($server.environmentReferences.Count) { "    Environment references (not resolved): $($server.environmentReferences -join ', ')" }
            "    $($server.remediation)"
        }
    }
    'Exact direct pins do not establish provenance, transitive reproducibility or absence of vulnerabilities.'
}
if ($report.classification -eq 'exact-pin') { exit 0 }
exit 1
