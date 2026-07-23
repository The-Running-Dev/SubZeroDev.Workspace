[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourcePath = (Join-Path $PWD.Path 'docs'),
    [string]$TemplatePath = (Join-Path $PWD.Path 'docs-template'),
    [string]$ReadmePath = (Join-Path $PWD.Path 'README.md'),
    [string]$OrganizationName = 'The-Running-Dev',
    [string]$RepositoryName = 'LLMs',
    [string]$SiteTitle = 'LLM Workspace Toolkit',
    [string]$SiteUrl = 'https://llms.subzerodev.com',
    [string]$BaseUrl = '/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'modules/Setup.psm1'
Import-Module $modulePath -Force

$resolvedSource = Resolve-OrCreatePath -Path $SourcePath -PathKind Directory
$resolvedTemplate = Resolve-OrCreatePath -Path $TemplatePath -PathKind Directory
$resolvedReadme = Resolve-OrCreatePath -Path $ReadmePath -PathKind File
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
    throw "The Template Path is not an Initialized Docusaurus Template: $resolvedTemplate. Run 'git submodule update --init --recursive' first."
}
if (-not (Test-Path -LiteralPath $globalConfigPath -PathType Leaf)) {
    throw "Template Configuration is Missing: $globalConfigPath"
}

if (-not (Test-Path -LiteralPath $sourceSidebarPath -PathType Leaf)) {
    if (Test-Path -LiteralPath $templateSidebarPath -PathType Leaf) {
        Copy-Item -LiteralPath $templateSidebarPath -Destination $sourceSidebarPath -Force
    }
    elseif (-not $WhatIfPreference) {
        New-Item -ItemType File -Path $sourceSidebarPath -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $sourceDocusaurusConfigPath -PathType Leaf)) {
    if (Test-Path -LiteralPath $templateDocusaurusConfigPath -PathType Leaf) {
        Copy-Item -LiteralPath $templateDocusaurusConfigPath -Destination $sourceDocusaurusConfigPath -Force
    }
    elseif (-not $WhatIfPreference) {
        New-Item -ItemType File -Path $sourceDocusaurusConfigPath -Force | Out-Null
    }
}

foreach ($projectConfigPath in @($sourceSidebarPath, $sourceDocusaurusConfigPath)) {
    if (-not (Test-Path -LiteralPath $projectConfigPath -PathType Leaf)) {
        if ($WhatIfPreference) {
            Write-Verbose "Path Would be Created in non-WhatIf Mode: $projectConfigPath"

            continue
        }

        throw "Project Documentation Override is Missing: $projectConfigPath"
    }
}
if ($resolvedSource -eq $resolvedTemplate -or $templateDocs -eq $resolvedSource) {
    throw 'The Documentation Source and Template Destination Must be Different Directories.'
}

if ($PSCmdlet.ShouldProcess($templateDocs, "Replace Template Documentation with Content from $resolvedSource")) {
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

if ($PSCmdlet.ShouldProcess($resolvedTemplate, 'Apply Project Docusaurus Configuration Overrides')) {
    Copy-Item -LiteralPath $sourceSidebarPath -Destination $templateSidebarPath -Force
    Copy-Item -LiteralPath $sourceDocusaurusConfigPath -Destination $templateDocusaurusConfigPath -Force
}

$normalizedSiteUrl = $SiteUrl.TrimEnd('/')
$normalizedBaseUrl = "/$($BaseUrl.Trim('/'))/"
if ($normalizedBaseUrl -eq '//') { $normalizedBaseUrl = '/' }

function Convert-ReadmeLinks {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DocumentationBase
    )

    $converted = $Content -replace '\]\(setup/docs/index\.md\)', "]($DocumentationBase/)"
    $converted = $converted -replace '\]\(setup/docs/\)', "]($DocumentationBase/)"
    $converted = $converted -replace '\]\(setup/\)', "]($repositoryUrl/tree/main/setup)"
    $converted = $converted -replace '\]\(docs-template/\)', "]($repositoryUrl/tree/main/docs-template)"
    $converted = $converted -replace '\]\(setup/docs/', "]($DocumentationBase/"
    $converted = $converted -replace '\]\(setup/', "]($repositoryUrl/blob/main/setup/"
    if ($DocumentationBase -ne '.') {
        $escapedDocumentationBase = [regex]::Escape($DocumentationBase)
        $converted = $converted -replace "(\]\($escapedDocumentationBase/[^)\s]+)\.md\)", '$1/)'
    }
    $converted
}

$rootReadmeContent = Get-Content -LiteralPath $resolvedReadme -Raw
$repositoryUrl = "https://github.com/$OrganizationName/$RepositoryName"
$readmeContent = Convert-ReadmeLinks -Content $rootReadmeContent -DocumentationBase '.'
$readmeFrontMatter = @"
---
title: $SiteTitle
id: template-overview
sidebar_position: 1
description: Canonical setup, project-generation, container, and repository guide.
---

"@
if ($PSCmdlet.ShouldProcess($templateDocsIndex, "Generate the Documentation Index from $resolvedReadme")) {
    Set-Content -LiteralPath $templateDocsIndex -Value ($readmeFrontMatter + $readmeContent) -NoNewline
}

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
if ($PSCmdlet.ShouldProcess($globalConfigPath, 'Configure the Generated GitHub Pages Site')) {
    Set-Content -LiteralPath $globalConfigPath -Value $globalConfig -NoNewline
}

$landingPage = @"
---
title: $SiteTitle
slug: /
---

$(Convert-ReadmeLinks -Content $rootReadmeContent -DocumentationBase "${normalizedBaseUrl}docs")
"@

if ($PSCmdlet.ShouldProcess($landingPagePath, 'Create the Documentation Landing Page')) {
    if (Test-Path -LiteralPath $reactLandingPagePath -PathType Leaf) {
        Remove-Item -LiteralPath $reactLandingPagePath -Force
    }
    Set-Content -LiteralPath $landingPagePath -Value $landingPage -NoNewline
}

if ($WhatIfPreference) {
    Write-Host 'Documentation Synchronization Preview Completed.' -ForegroundColor Yellow
}
else {
    Write-Host "Documentation Synchronized to $templateDocs" -ForegroundColor Green
    Write-Host "Configured Documentation URL: $normalizedSiteUrl$normalizedBaseUrl"
}
