[CmdletBinding(SupportsShouldProcess)]
param()

. (Join-Path $PSScriptRoot '..\..\modules\Common.ps1')

Write-Step 'Installing optional third-party claude-mem'
Assert-CommandAvailable -Name 'node' -InstallHint 'Install the current Node.js LTS release first.'
Assert-CommandAvailable -Name 'npm' -InstallHint 'Install npm with the current Node.js LTS release first.'
Assert-CommandAvailable -Name 'claude' -InstallHint 'Install Claude Code first.'

Write-WarningMessage 'claude-mem captures and stores coding-session activity. Review its privacy, storage, sync, and exclusion settings before private-repository use.'

if ($PSCmdlet.ShouldProcess('claude-mem', 'Install the official npm package globally')) {
    # npx/npm exec can intermittently omit the temporary package bin directory
    # on Windows. A global install creates a stable command shim that can also
    # be resolved by absolute path in the current PowerShell session.
    Invoke-NativeCommand -FilePath 'npm' -ArgumentList @(
        'install', '--global', 'claude-mem@latest'
    )
    Update-SessionPath
}

if (-not $WhatIfPreference) {
    $npmPrefix = (& npm prefix --global 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($npmPrefix)) {
        throw 'Could not determine the global npm command directory.'
    }

    $claudeMemCommand = Join-Path $npmPrefix 'claude-mem.cmd'
    if (-not (Test-Path -LiteralPath $claudeMemCommand -PathType Leaf)) {
        throw "claude-mem was installed, but its command shim was not found at: $claudeMemCommand"
    }

    if ($PSCmdlet.ShouldProcess('claude-mem', 'Install hooks and worker')) {
        Invoke-NativeCommand -FilePath $claudeMemCommand -ArgumentList @('install')
    }

    if ($PSCmdlet.ShouldProcess('claude-mem worker', 'Start the local memory worker')) {
        Invoke-NativeCommand -FilePath $claudeMemCommand -ArgumentList @('start')
    }
}
else {
    $null = $PSCmdlet.ShouldProcess('claude-mem', 'Install hooks and worker')
    $null = $PSCmdlet.ShouldProcess('claude-mem worker', 'Start the local memory worker')
}

Write-Success 'claude-mem installation finished and its worker was started. Restart Claude Code before testing it.'
