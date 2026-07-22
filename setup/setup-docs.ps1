[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot 'docs'),
    [string]$TemplatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs-template'),
    [string]$ReadmePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'README.md'),
    [string]$OrganizationName = 'The-Running-Dev',
    [string]$RepositoryName = 'LLMs',
    [string]$SiteTitle = 'LLM Workspace Toolkit',
    [string]$SiteUrl = 'https://llms.subzerodev.com',
    [string]$BaseUrl = '/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedSource = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$resolvedTemplate = (Resolve-Path -LiteralPath $TemplatePath -ErrorAction Stop).Path
$resolvedReadme = (Resolve-Path -LiteralPath $ReadmePath -ErrorAction Stop).Path
$templatePackage = Join-Path $resolvedTemplate 'package.json'
$templateDocs = Join-Path $resolvedTemplate 'docs'
$templateDocsIndex = Join-Path $templateDocs 'index.md'
$globalConfigPath = Join-Path $resolvedTemplate 'config/globalConfig.yml'
$sourceSidebarPath = Join-Path $resolvedSource 'sidebars.ts'
$sourceDocusaurusConfigPath = Join-Path $resolvedSource 'docusaurus.config.ts'
$templateSidebarPath = Join-Path $resolvedTemplate 'sidebars.ts'
$templateDocusaurusConfigPath = Join-Path $resolvedTemplate 'docusaurus.config.ts'
$landingPagePath = Join-Path $resolvedTemplate 'src/pages/index.md'
$reactLandingPagePath = Join-Path $resolvedTemplate 'src/pages/index.tsx'

if (-not (Test-Path -LiteralPath $templatePackage -PathType Leaf)) {
    throw "The template path is not an initialized Docusaurus template: $resolvedTemplate. Run 'git submodule update --init --recursive' first."
}
if (-not (Test-Path -LiteralPath $globalConfigPath -PathType Leaf)) {
    throw "Template configuration is missing: $globalConfigPath"
}
foreach ($projectConfigPath in @($sourceSidebarPath, $sourceDocusaurusConfigPath)) {
    if (-not (Test-Path -LiteralPath $projectConfigPath -PathType Leaf)) {
        throw "Project documentation override is missing: $projectConfigPath"
    }
}
if ($resolvedSource -eq $resolvedTemplate -or $templateDocs -eq $resolvedSource) {
    throw 'The documentation source and template destination must be different directories.'
}

if ($PSCmdlet.ShouldProcess($templateDocs, "Replace template documentation with content from $resolvedSource")) {
    if (Test-Path -LiteralPath $templateDocs -PathType Container) {
        Get-ChildItem -LiteralPath $templateDocs -Force | Remove-Item -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path $templateDocs -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $resolvedSource -Force |
        Where-Object { $_.Name -notin @('sidebars.ts', 'docusaurus.config.ts') } |
        Copy-Item -Destination $templateDocs -Recurse -Force
}

if ($PSCmdlet.ShouldProcess($resolvedTemplate, 'Apply project-owned Docusaurus configuration overrides')) {
    Copy-Item -LiteralPath $sourceSidebarPath -Destination $templateSidebarPath -Force
    Copy-Item -LiteralPath $sourceDocusaurusConfigPath -Destination $templateDocusaurusConfigPath -Force
}

$readmeContent = Get-Content -LiteralPath $resolvedReadme -Raw
$repositoryUrl = "https://github.com/$OrganizationName/$RepositoryName"
$readmeContent = $readmeContent -replace '\]\(setup/docs/\)', '](.)'
$readmeContent = $readmeContent -replace '\]\(setup/\)', "]($repositoryUrl/tree/main/setup)"
$readmeContent = $readmeContent -replace '\]\(docs-template/\)', "]($repositoryUrl/tree/main/docs-template)"
$readmeContent = $readmeContent -replace '\]\(setup/docs/', ']('
$readmeContent = $readmeContent -replace '\]\(setup/', "]($repositoryUrl/blob/main/setup/"
$readmeFrontMatter = @"
---
title: LLM Workspace Toolkit
id: template-overview
sidebar_position: 1
description: Canonical setup, project-generation, container, and repository guide.
---

"@
if ($PSCmdlet.ShouldProcess($templateDocsIndex, "Generate the documentation index from $resolvedReadme")) {
    Set-Content -LiteralPath $templateDocsIndex -Value ($readmeFrontMatter + $readmeContent) -NoNewline
}

$normalizedSiteUrl = $SiteUrl.TrimEnd('/')
$normalizedBaseUrl = "/$($BaseUrl.Trim('/'))/"
if ($normalizedBaseUrl -eq '//') { $normalizedBaseUrl = '/' }
$globalConfig = Get-Content -LiteralPath $globalConfigPath -Raw
$configReplacements = [ordered]@{
    '(?m)^  title: .*$' = "  title: $SiteTitle"
    '(?m)^  tagline: .*$' = '  tagline: Cross-platform setup for Codex and Claude Code'
    '(?m)^  url: .*$' = "  url: $normalizedSiteUrl"
    '(?m)^  baseUrl: .*$' = "  baseUrl: $normalizedBaseUrl"
    '(?m)^  organizationName: .*$' = "  organizationName: $OrganizationName"
    '(?m)^  projectName: .*$' = "  projectName: $RepositoryName"
    '(?m)^    title: .*$' = "    title: $SiteTitle"
}
foreach ($replacement in $configReplacements.GetEnumerator()) {
    $globalConfig = $globalConfig -replace $replacement.Key, $replacement.Value
}
if ($PSCmdlet.ShouldProcess($globalConfigPath, 'Configure the generated GitHub Pages site')) {
    Set-Content -LiteralPath $globalConfigPath -Value $globalConfig -NoNewline
}

$landingPage = @"
---
title: $SiteTitle
slug: /
---

# $SiteTitle

Cross-platform PowerShell tooling for configuring Codex and Claude Code and scaffolding new AI-assisted projects.

[Open the setup documentation](${normalizedBaseUrl}docs/)
"@

if ($PSCmdlet.ShouldProcess($landingPagePath, 'Create the documentation landing page')) {
    if (Test-Path -LiteralPath $reactLandingPagePath -PathType Leaf) {
        Remove-Item -LiteralPath $reactLandingPagePath -Force
    }
    Set-Content -LiteralPath $landingPagePath -Value $landingPage -NoNewline
}

if ($WhatIfPreference) {
    Write-Host 'Documentation synchronization preview completed.' -ForegroundColor Yellow
}
else {
    Write-Host "Documentation synchronized to $templateDocs" -ForegroundColor Green
    Write-Host "Configured documentation URL: $normalizedSiteUrl$normalizedBaseUrl"
}
