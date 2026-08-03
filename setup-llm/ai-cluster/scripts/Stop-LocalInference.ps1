[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StatePath = (Join-Path $PSScriptRoot '../state')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedState = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $StatePath -Force)).Path
$pidFile = Join-Path $resolvedState 'pids.json'

Write-Host 'Issue #16 T3 skeleton: no managed local inference processes are started yet.' -ForegroundColor Yellow

if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) {
    Write-Host "No PID state file found at $pidFile"
    return
}

$pids = Get-Content -LiteralPath $pidFile -Raw | ConvertFrom-Json
foreach ($entry in $pids.providers) {
    if (-not $entry.pid) { continue }
    if ($PSCmdlet.ShouldProcess("PID $($entry.pid)", "Stop provider '$($entry.name)'")) {
        try {
            Stop-Process -Id ([int]$entry.pid) -ErrorAction Stop
            Write-Host "Stopped $($entry.name) (PID $($entry.pid))."
        }
        catch {
            Write-Warning "Could not stop $($entry.name) PID $($entry.pid): $_"
        }
    }
}
