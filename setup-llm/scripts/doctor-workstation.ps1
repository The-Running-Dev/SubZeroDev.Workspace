[CmdletBinding()]
param(
    [ValidateSet('Codex', 'ClaudeCode', 'Both')]
    [string]$Client = 'Both',
    [switch]$AsJson,
    [switch]$ConversationCapabilities,
    [string]$CapabilityEvidencePath,
    [string]$GraphifyPackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-DockerEngineRunning {
    try {
        & docker info *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-McpServerRegistered {
    param(
        [Parameter(Mandatory)][ValidateSet('codex', 'claude')][string]$ClientName,
        [Parameter(Mandatory)][string]$ServerName
    )

    if (-not (Get-Command $ClientName -ErrorAction SilentlyContinue)) {
        return $false
    }

    $output = & $ClientName mcp list 2>&1 | Out-String
    return $output -match "(?im)\b$([regex]::Escape($ServerName))\b"
}

$profiles = @(
    [ordered]@{ name = 'github'; requiresDocker = $true; optional = $false; description = 'GitHub MCP server (read-only, Docker Compose managed)' }
    [ordered]@{ name = 'playwright'; requiresDocker = $false; optional = $false; description = 'Playwright MCP server' }
    [ordered]@{ name = 'filesystem'; requiresDocker = $false; optional = $false; description = 'Filesystem MCP server' }
    [ordered]@{ name = 'context7'; requiresDocker = $false; optional = $true; description = 'Context7 MCP server' }
    [ordered]@{ name = 'memory'; requiresDocker = $false; optional = $true; description = 'Memory MCP server (shared multi-agent memory)' }
    [ordered]@{ name = 'docker'; requiresDocker = $true; optional = $true; description = 'Docker MCP gateway' }
)

$clients = switch ($Client) {
    'Codex' { @('codex') }
    'ClaudeCode' { @('claude') }
    default { @('codex', 'claude') }
}

$results = @()
foreach ($clientName in $clients) {
    foreach ($profile in $profiles) {
        $registered = Test-McpServerRegistered -ClientName $clientName -ServerName $profile.name
        $dockerReady = if ($profile.requiresDocker) { Test-DockerEngineRunning } else { $true }
        $status = if ($registered -and $dockerReady) { 'healthy' } elseif (-not $registered) { 'missing' } elseif (-not $dockerReady) { 'docker-unavailable' } else { 'warning' }

        $results += [ordered]@{
            client = $clientName
            profile = $profile.name
            status = $status
            description = $profile.description
            optional = $profile.optional
        }
    }
}

$unhealthyRequiredProfiles = @($results | Where-Object { $_.status -ne 'healthy' -and -not $_.optional }).Count

$capabilityReport = $null
if ($ConversationCapabilities) {
    Import-Module (Join-Path $PSScriptRoot 'modules/ConversationCapabilities.psm1') -Force
    $capabilityReport = Get-ConversationCapabilityReport -EvidencePath $CapabilityEvidencePath -GraphifyPackagePath $GraphifyPackagePath
}

if ($AsJson) {
    if ($ConversationCapabilities) { [ordered]@{ profiles = $results; conversationCapabilities = $capabilityReport } | ConvertTo-Json -Depth 18 }
    else { $results | ConvertTo-Json -Depth 6 }
}
else {
    Write-Host 'Workstation MCP profile doctor:' -ForegroundColor Cyan
    foreach ($entry in $results) {
        $color = switch ($entry.status) {
            'healthy' { 'Green' }
            'missing' { 'Yellow' }
            'docker-unavailable' { 'Yellow' }
            default { 'Red' }
        }

        Write-Host ("- {0}/{1}: {2} ({3})" -f $entry.client, $entry.profile, $entry.status, $entry.description) -ForegroundColor $color
    }
    if ($ConversationCapabilities) {
        foreach ($entry in $capabilityReport.capabilities) { Write-Host ("- {0}: {1} [{2}]" -f $entry.id, $entry.status, $entry.evidence.code) }
    }
}

if ($unhealthyRequiredProfiles -gt 0) {
    exit 1
}

exit 0
