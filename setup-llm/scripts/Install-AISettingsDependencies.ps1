#Requires -Version 7.0
<#
.SYNOPSIS
Installs the AI settings engine's locked dependencies for development and CI.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packageRoot = Join-Path $PSScriptRoot '..'
# npm.ps1 reparses PowerShell source; invoke the native shim with evaluated arguments.
$npmExecutable = if ($IsWindows) { 'npm.cmd' } else { 'npm' }
& $npmExecutable ci --prefix $packageRoot --ignore-scripts --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw 'AI settings dependency installation failed.' }
