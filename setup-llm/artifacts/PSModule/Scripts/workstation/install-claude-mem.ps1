[CmdletBinding(SupportsShouldProcess)]
param()
$modulePath = Join-Path $PSScriptRoot '../modules/Setup.psm1'
Import-Module $modulePath -Force

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
        throw 'Could not determine the global npm prefix.'
    }

    # npm's generated Windows .cmd shim can double-quote `node` and fail with
    # '"node" is not recognized'. Invoke the package entry point through the
    # resolved Node executable instead. Account for npm's Windows and Unix
    # global package layouts.
    $nodeCommand = (Get-Command 'node' -ErrorAction Stop).Source
    $entrypointCandidates = @(
        (Join-Path $npmPrefix 'node_modules/claude-mem/dist/npx-cli/index.js'),
        (Join-Path $npmPrefix 'lib/node_modules/claude-mem/dist/npx-cli/index.js')
    )
    $claudeMemEntrypoint = $entrypointCandidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if (-not $claudeMemEntrypoint) {
        throw "claude-mem was installed, but its JavaScript entry point could not be found under: $npmPrefix"
    }

    if ($PSCmdlet.ShouldProcess('claude-mem', 'Install hooks and worker')) {
        Invoke-NativeCommand -FilePath $nodeCommand -ArgumentList @($claudeMemEntrypoint, 'install')
    }

    if ($PSCmdlet.ShouldProcess('claude-mem worker', 'Start the local memory worker')) {
        Invoke-NativeCommand -FilePath $nodeCommand -ArgumentList @($claudeMemEntrypoint, 'start')
    }
}
else {
    $null = $PSCmdlet.ShouldProcess('claude-mem', 'Install hooks and worker')
    $null = $PSCmdlet.ShouldProcess('claude-mem worker', 'Start the local memory worker')
}

if ($WhatIfPreference) {
    Write-Success 'claude-mem installation preview completed.'
}
else {
    Write-Success 'claude-mem installation finished and its worker was started. Restart Claude Code before testing it.'
}
