#Requires -Version 7.0
<#
.SYNOPSIS
Installs the AI settings engine's locked dependencies for development and CI.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
& npm ci --prefix (Join-Path $PSScriptRoot '..') --ignore-scripts --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw 'AI settings dependency installation failed.' }
