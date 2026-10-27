#Requires -Version 7.4
<#
.SYNOPSIS
Report read-only conversation host, Graphify, MemoryKit and VS Code capabilities.
.DESCRIPTION
Runs only bounded graphify --version and codex mcp list --json probes. Reads explicit
installed package sources, AgentKit memory configuration metadata and extension
manifests. No conversation content, store contents, configurations or probe output
are copied into the report. See docs/reference/conversation-capabilities.md.
Optional unavailable/unknown integrations exit 0; invocation errors exit 2.
#>
[CmdletBinding()]
param(
    [string]$GraphifyPackagePath,
    [string]$MemoryConfigPath,
    [string]$Namespace,
    [string]$ExtensionsPath,
    [string]$EvidencePath,
    [switch]$AsJson
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'modules/ConversationCapabilities.psm1') -Force
try {
    $report = Get-ConversationCapabilityReport -GraphifyPackagePath $GraphifyPackagePath -MemoryConfigPath $MemoryConfigPath -Namespace $Namespace -ExtensionsPath $ExtensionsPath -EvidencePath $EvidencePath
    if ($AsJson) { $report | ConvertTo-Json -Depth 16 }
    else {
        'Conversation capability report (read-only; optional integrations):'
        foreach ($entry in $report.capabilities) { '{0}: {1} [{2}] — {3}' -f $entry.id, $entry.status, $entry.evidence.code, $entry.nextStep }
        ''
        $report.adapters | Format-Table operation, adapter, status -AutoSize
    }
    exit 0
}
catch {
    if ($AsJson) { '{"schemaVersion":1,"error":"report-invocation-failed"}' }
    else { 'Capability report could not complete; check local input access and PowerShell version.' }
    exit 2
}
