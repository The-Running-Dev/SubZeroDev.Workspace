#Requires -Version 7.4
<#
.SYNOPSIS
Project explicitly selected conversation metadata using the installed Graphify environment.
.DESCRIPTION
PythonPath must identify the existing graphifyy environment's Python executable.
SelectionPath is reviewed metadata, never a private branch manifest or archive.
Omit SelectionPath to rebuild the persisted selection, preserving exclusions.
Exit 0: built; 3: optional Graphify unavailable/failed; 2: invalid invocation.
See docs/reference/conversation-projection.md for selection and removal semantics.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PythonPath,
    [Parameter(Mandatory)][string]$StateRoot,
    [string]$SelectionPath
)
$ErrorActionPreference = 'Stop'
try {
    $arguments = @('-I', (Join-Path $PSScriptRoot 'conversation_projection.py'), '--state-root', $StateRoot)
    if ($SelectionPath) { $arguments += @('--selection', $SelectionPath) }
    & $PythonPath @arguments
    exit $LASTEXITCODE
}
catch {
    '{"status":"error","code":"python-invocation-failed"}'
    exit 2
}
