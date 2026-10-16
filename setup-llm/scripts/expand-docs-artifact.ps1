[CmdletBinding()]
param(
    [string]$ArtifactPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'docs-template/pages-artifact'),
    [string]$DestinationPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'docs-template/artifacts')
)

# The documentation workflow's container job downloads the Pages artifact of the
# docs build (a tar of the built site) into $ArtifactPath. The Dockerfile's
# runtime-prebuilt stage copies the site from docs-template/artifacts, so the
# archive is unpacked there and the download is removed from the build context.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archive = Join-Path $ArtifactPath 'artifact.tar'
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw "The Documentation Artifact is Missing: $archive"
}

New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
& tar -xf $archive -C $DestinationPath
if ($LASTEXITCODE -ne 0) {
    throw "Unpacking the Documentation Artifact Failed: $archive"
}
if (-not (Test-Path -LiteralPath (Join-Path $DestinationPath 'index.html') -PathType Leaf)) {
    throw "The Documentation Artifact has no index.html: $archive"
}

Remove-Item -LiteralPath $ArtifactPath -Recurse -Force
Write-Host "Unpacked the documentation site into $DestinationPath"
