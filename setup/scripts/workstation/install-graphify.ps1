[CmdletBinding(SupportsShouldProcess)]
param()

. (Join-Path $PSScriptRoot '..\..\modules\Common.ps1')

Write-Step 'Installing Graphify'

if (-not (Test-CommandAvailable -Name 'uv')) {
    Update-SessionPath
}

if (-not (Test-CommandAvailable -Name 'uv')) {
    Assert-CommandAvailable -Name 'winget' -InstallHint 'Install uv from https://docs.astral.sh/uv/getting-started/installation/ and rerun this script.'
    if ($PSCmdlet.ShouldProcess('Astral uv', 'Install with winget')) {
        Invoke-NativeCommand -FilePath 'winget' -ArgumentList @(
            'install', '--id', 'astral-sh.uv', '--exact',
            '--accept-package-agreements', '--accept-source-agreements'
        )
        Update-SessionPath
    }
}

# In preview mode uv has intentionally not been installed, so commands that
# depend on it cannot be inspected or executed yet. Still include the remaining
# Graphify actions in the WhatIf output, then finish the preview successfully.
if ($WhatIfPreference -and -not (Test-CommandAvailable -Name 'uv')) {
    $null = $PSCmdlet.ShouldProcess('graphifyy', 'Install or upgrade uv tool')
    $null = $PSCmdlet.ShouldProcess('Detected coding assistants', 'Register the Graphify skill')
    Write-Success 'Preview complete. A real run will install uv before Graphify.'
    return
}

if (-not (Test-CommandAvailable -Name 'uv')) {
    $uvCandidate = Join-Path $env:USERPROFILE '.local\bin\uv.exe'
    if (Test-Path -LiteralPath $uvCandidate) {
        $env:PATH = "$(Split-Path -Parent $uvCandidate);$env:PATH"
    }
}

Assert-CommandAvailable -Name 'uv' -InstallHint 'Restart PowerShell if uv was just installed, then rerun.'

if ($PSCmdlet.ShouldProcess('graphifyy', 'Install or upgrade uv tool')) {
    $installedTools = & uv tool list 2>&1 | Out-String
    if ($installedTools -match '(?m)^graphifyy\s') {
        Invoke-NativeCommand -FilePath 'uv' -ArgumentList @('tool', 'upgrade', 'graphifyy')
    }
    else {
        Invoke-NativeCommand -FilePath 'uv' -ArgumentList @('tool', 'install', 'graphifyy')
    }
}


# When uv is already available but Graphify is not, WhatIf must not require the
# executable that the preview deliberately declined to install.
if ($WhatIfPreference -and -not (Test-CommandAvailable -Name 'graphify')) {
    $null = $PSCmdlet.ShouldProcess('Detected coding assistants', 'Register the Graphify skill')
    Write-Success 'Preview complete. A real run will install Graphify before registering its skill.'
    return
}

if (-not (Test-CommandAvailable -Name 'graphify')) {
    $uvToolBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path -LiteralPath $uvToolBin) { $env:PATH = "$uvToolBin;$env:PATH" }
}

Assert-CommandAvailable -Name 'graphify' -InstallHint 'Restart PowerShell so the uv tool directory is added to PATH.'
if ($PSCmdlet.ShouldProcess('Detected coding assistants', 'Register the Graphify skill')) {
    Invoke-NativeCommand -FilePath 'graphify' -ArgumentList @('install')
}

Write-Success 'Graphify is installed. In a repository, run /graphify . from a supported coding assistant.'
