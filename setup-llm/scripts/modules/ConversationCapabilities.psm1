#Requires -Version 7.4
Set-StrictMode -Version Latest

function Read-CapabilityJson {
    param([string]$Path)
    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file -isnot [IO.FileInfo] -or $file.Length -gt 2MB) { throw 'Unsupported input.' }
    Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -Depth 32 -ErrorAction Stop
}

function Invoke-CapabilityProbe {
    param([string]$Command, [string[]]$Arguments, [int]$TimeoutMilliseconds = 10000)
    # Only fixed, read-only commands from this module reach this boundary. No command
    # taken from a configuration, extension manifest or evidence document is executed.
    $executable = Get-Command $Command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$executable) { return @{ state = 'unavailable'; code = 'command-absent'; output = '' } }
    $process = [Diagnostics.Process]::new()
    try {
        # A child pwsh handles .cmd and .ps1 shims on Windows as well as native binaries.
        # JSON is data, never interpolated into shell syntax; stdout/stderr are not reported.
        $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((@{ command = $executable.Source; arguments = @($Arguments) } | ConvertTo-Json -Compress)))
        $program = '$p = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(''' + $payload + ''')) | ConvertFrom-Json; $a = @($p.arguments); & $p.command @a; if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }'
        $process.StartInfo.FileName = (Get-Process -Id $PID).Path
        foreach ($arg in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($program)))) { $process.StartInfo.ArgumentList.Add($arg) }
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            return @{ state = 'unknown'; code = 'probe-timeout'; output = '' }
        }
        $null = $stderr.GetAwaiter().GetResult()
        $output = $stdout.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { return @{ state = 'unknown'; code = 'probe-failed'; output = '' } }
        if ($output.Length -gt 2MB) { return @{ state = 'unknown'; code = 'probe-output-too-large'; output = '' } }
        return @{ state = 'supported'; code = 'probe-succeeded'; output = $output }
    }
    catch { return @{ state = 'unknown'; code = 'probe-failed'; output = '' } }
    finally { $process.Dispose() }
}

function New-Capability {
    param([string]$Id, [string]$Status, [string]$Code, [string]$NextStep, [hashtable]$Details = @{})
    [ordered]@{ id = $Id; status = $Status; evidence = [ordered]@{ code = $Code; details = $Details }; nextStep = $NextStep }
}

function Get-GraphifyCapabilities {
    param([string]$PackagePath)
    $probe = Invoke-CapabilityProbe 'graphify' @('--version')
    $version = $null
    if ($probe.state -eq 'supported' -and $probe.output.Trim() -cmatch '^graphify ([0-9]+\.[0-9]+\.[0-9]+)$') { $version = $Matches[1] }
    $status = if ($version) { 'supported' } elseif ($probe.state -eq 'unavailable') { 'unavailable' } else { 'unknown' }
    New-Capability 'graphify.cli' $status $(if ($version) { 'version-probed' } else { $probe.code }) 'Supply -GraphifyPackagePath from the installed graphifyy environment to inspect its mechanisms.' @{ version = $version; functionalGraph = 'not-probed' }
    # The caller identifies the installed package directory. These hashes attest the
    # supplied source declarations, not that this directory backs the CLI on PATH.
    $specs = @(
        @{ id = 'graphify.inputs'; file = 'detect.py'; patterns = @('DOC_EXTENSIONS\s*=', "'\.md'", "'\.txt'"); mechanism = 'document extensions include .md and .txt' }
        @{ id = 'graphify.relationships'; file = 'validate.py'; patterns = @('REQUIRED_EDGE_FIELDS\s*=', '"source"', '"target"', '"relation"', '"confidence"', '"source_file"'); mechanism = 'extraction nodes/edges with attributed relationships; conversation semantics unverified' }
        @{ id = 'graphify.exclusions'; file = 'detect.py'; patterns = @('extra_excludes', '\.gitignore'); mechanism = 'extra_excludes and gitignore discovery rules; validate scope before indexing private material' }
    )
    foreach ($spec in $specs) {
        $details = @{ mechanism = $null; sourceSha256 = $null }
        $code = 'package-source-not-supplied'
        $state = 'unknown'
        if ($PackagePath) {
            try {
                $file = Get-Item -LiteralPath (Join-Path $PackagePath $spec.file) -ErrorAction Stop
                if ($file.Length -gt 2MB) { throw 'Too large.' }
                $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
                $matchesAll = @($spec.patterns | Where-Object { $text -notmatch $_ }).Count -eq 0
                $details.sourceSha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($matchesAll -and $version) { $state = 'supported'; $code = 'supplied-source-declaration'; $details.mechanism = $spec.mechanism }
                else { $code = 'source-contract-unrecognized' }
            }
            catch { $code = 'package-source-unreadable' }
        }
        New-Capability $spec.id $state $code 'Review the installed source and Graphify skill; a declaration is not a tested conversation adapter.' $details
    }
}

function Get-MemoryCapabilities {
    param([string]$ConfigPath, [string]$Namespace)
    $details = @{ configurationPresent = $false; cliAvailable = $false; storePresent = $false; captureEnabled = $false; contextEnabled = $false; namespaceSelected = [bool]$Namespace }
    $state = 'unconfigured'; $code = 'configuration-absent'
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        $details.configurationPresent = $true
        try {
            $config = Read-CapabilityJson $ConfigPath
            if ($config -isnot [System.Collections.IDictionary] -or $config.cli -isnot [string] -or !$config.cli -or $config.store -isnot [string] -or !$config.store) { throw 'Invalid configuration.' }
            $details.cliAvailable = if ([IO.Path]::IsPathRooted($config.cli)) { Test-Path -LiteralPath $config.cli -PathType Leaf } else { [bool](Get-Command $config.cli -CommandType Application, ExternalScript -ErrorAction SilentlyContinue) }
            $details.storePresent = Test-Path -LiteralPath (Join-Path $config.store 'memory.db') -PathType Leaf
            $details.captureEnabled = $config.Contains('capture') -and $config.capture -eq $true
            $details.contextEnabled = $config.Contains('context') -and $config.context -eq $true
            $state = if (!$details.cliAvailable) { 'unavailable' } elseif (!$details.storePresent) { 'unconfigured' } else { 'unknown' }
            $code = if (!$details.cliAvailable) { 'configured-cli-absent' } elseif (!$details.storePresent) { 'configured-store-absent' } else { 'configuration-found-runtime-not-probed' }
        }
        catch { $state = 'unknown'; $code = 'configuration-unreadable-or-invalid' }
    }
    New-Capability 'memorykit.configuration' $state $code 'Use the existing AgentKit /memory configuration workflow if desired; this report never enables it or opens the store.' $details
    New-Capability 'memorykit.namespace' $(if ($Namespace) { 'unknown' } else { 'unconfigured' }) $(if ($Namespace) { 'selected-namespace-not-probed' } else { 'namespace-not-selected' }) 'Supply -Namespace for the intended scope and record read-only namespace/access evidence; do not infer access from configuration.' @{ selected = [bool]$Namespace; storeOpened = $false }
    $probe = Invoke-CapabilityProbe 'codex' @('mcp', 'list', '--json')
    $state = $probe.state; $code = $probe.code; $registered = $false
    if ($state -eq 'supported') {
        try {
            $servers = ConvertFrom-Json -InputObject $probe.output -AsHashtable -NoEnumerate -ErrorAction Stop
            if ($servers -isnot [array]) { throw 'Unknown list shape.' }
            $registered = @($servers | Where-Object { $_.name -ceq 'memory' -and (!$_.Contains('enabled') -or $_.enabled -eq $true) }).Count -gt 0
            $state = if ($registered) { 'unknown' } else { 'unconfigured' }
            $code = if ($registered) { 'registered-runtime-not-probed' } else { 'registration-absent' }
        }
        catch { $state = 'unknown'; $code = 'registration-output-unrecognized' }
    }
    New-Capability 'memory-mcp.codex' $state $code 'Registration is not functional success or a MemoryKit store; inspect active session tools separately. Claude Code registration remains in the baseline doctor.' @{ registered = $registered; functional = 'not-probed' }
}

function Get-EditorCapabilities {
    param([string]$ExtensionsPath)
    $extensions = [Collections.Generic.List[object]]::new()
    $state = 'unavailable'; $code = 'extension-directory-absent'
    if (Test-Path -LiteralPath $ExtensionsPath -PathType Container) {
        $state = 'unconfigured'; $code = 'memory-extension-not-found'
        try {
            $invalidManifests = 0
            foreach ($directory in Get-ChildItem -LiteralPath $ExtensionsPath -Directory -ErrorAction Stop) {
              try {
                $manifestPath = Join-Path $directory.FullName 'package.json'
                if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
                $manifest = Read-CapabilityJson $manifestPath
                if ($manifest.publisher -isnot [string] -or $manifest.name -isnot [string]) { continue }
                $id = "$($manifest.publisher).$($manifest.name)"
                if ($id -cnotmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' -or $manifest.version -cnotmatch '^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$') { continue }
                $commands = @()
                if ($manifest.Contains('contributes') -and $manifest.contributes.Contains('commands')) {
                    $commands = @($manifest.contributes.commands | Where-Object { $_.command -is [string] -and $_.command -cmatch '^[A-Za-z0-9_.-]{1,160}$' -and ($_.command -match 'memory' -or ($_.Contains('title') -and $_.title -match 'memory')) } | ForEach-Object { $_.command })
                }
                if ($commands.Count -or $manifest.name -match 'memory') {
                    $extensions.Add(@{ id = $id; version = $manifest.version; commands = $commands; sourceSha256 = (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() })
                }
              }
              catch { $invalidManifests++ }
            }
            if ($extensions.Count) { $state = 'unknown'; $code = 'manifest-declarations-only' }
            elseif ($invalidManifests) { $state = 'unknown'; $code = 'extension-manifest-unreadable' }
        }
        catch { $state = 'unknown'; $code = 'extension-manifest-unreadable' }
    }
    New-Capability 'vscode.memory' $state $code 'Inspect the active VS Code profile and extension documentation; verify declared commands manually. CLI inventory cannot prove editor activation.' @{ extensions = @($extensions.ToArray()); functional = 'not-probed'; scope = 'supplied local extension directory only' }
}

function Get-ManualCapabilities {
    param([string]$EvidencePath)
    $names = @('create_thread', 'fork_thread', 'navigate_to_codex_page', 'read_thread')
    $manual = $null; $hash = $null; $code = 'manual-evidence-not-supplied'
    if ($EvidencePath) {
        try {
            $manual = Read-CapabilityJson $EvidencePath
            if ($manual.schemaVersion -ne 1 -or $manual.host.name -cne 'codex' -or $manual.host.version -cnotmatch '^\d+(?:\.\d+){1,3}$') { throw 'Invalid evidence.' }
            # ConvertFrom-Json materializes ISO timestamps as DateTime on supported
            # PowerShell releases; never round-trip that through culture-specific text.
            $date = if ($manual.observedAt -is [datetime]) { [DateTimeOffset]$manual.observedAt } else { [DateTimeOffset]::ParseExact($manual.observedAt, 'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) }
            if ($date -gt [DateTimeOffset]::UtcNow.AddMinutes(5) -or $date -lt [DateTimeOffset]::UtcNow.AddDays(-7)) { throw 'Stale evidence.' }
            if ($manual.host.tools -isnot [array]) { throw 'Invalid tools.' }
            $seen = @{}
            foreach ($tool in $manual.host.tools) {
                if ($tool.name -cnotin $names -or $seen.ContainsKey($tool.name) -or $tool.status -cnotin @('supported', 'unavailable', 'unknown') -or $tool.verification -cnotin @('contract', 'smoke')) { throw 'Invalid tool.' }
                $seen[$tool.name] = $true
            }
            $hash = (Get-FileHash -LiteralPath $EvidencePath).Hash.ToLowerInvariant()
            $code = 'operator-evidence'
        }
        catch { $manual = $null; $code = 'manual-evidence-invalid-or-stale' }
    }
    foreach ($name in $names) {
        $state = 'unknown'; $details = @{ verification = 'none'; evidenceSha256 = $hash; hostVersion = $null }
        if ($manual) {
            $tool = @($manual.host.tools | Where-Object { $_.name -ceq $name })
            if ($tool.Count) { $state = $tool[0].status; $details.verification = $tool[0].verification; $details.hostVersion = $manual.host.version }
        }
        New-Capability "host.$name" $state $code 'Inspect current session tool contracts; record exact tool exposure and separately any authorized synthetic smoke result in the evidence file.' $details
    }
    $state = 'unknown'; $details = @{ ownerIdentified = $false; contractSha256 = $null; verification = 'none' }; $graphCode = 'live-owner-not-verified'
    if ($manual -and $manual.Contains('contextGraph')) {
        try {
            $graph = $manual.contextGraph
            if ($graph.status -cnotin @('supported', 'unavailable', 'unconfigured', 'unknown')) { throw 'Invalid graph status.' }
            if ($graph.status -eq 'supported') {
                if ($graph.live -cne $true -or $graph.owner -isnot [string] -or !$graph.owner -or $graph.contractPath -isnot [string] -or $graph.contractPath -match '[/\\]design[/\\]') { throw 'Not a live contract.' }
                $details.contractSha256 = (Get-FileHash -LiteralPath $graph.contractPath -ErrorAction Stop).Hash.ToLowerInvariant()
                $details.ownerIdentified = $true
            }
            $state = $graph.status; $details.verification = 'operator-evidence'; $graphCode = 'operator-evidence'
        }
        catch { $graphCode = 'live-contract-unverified' }
    }
    New-Capability 'context-graph.live' $state $graphCode 'Locate the live owner and current read/write contract before Workspace #57; historical AgentKit design state is not an API.' $details
}

function Get-ConversationCapabilityReport {
    [CmdletBinding()]
    param([string]$GraphifyPackagePath, [string]$MemoryConfigPath, [string]$Namespace, [string]$ExtensionsPath, [string]$EvidencePath)
    $agentKitHome = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    if (!$MemoryConfigPath) { $MemoryConfigPath = if ($env:AGENTKIT_MEMORYKIT_CONFIG) { $env:AGENTKIT_MEMORYKIT_CONFIG } else { Join-Path $agentKitHome '.agent-kit-state/memorykit.json' } }
    if (!$ExtensionsPath) { $ExtensionsPath = Join-Path $HOME '.vscode/extensions' }
    $capabilities = @(
        Get-GraphifyCapabilities $GraphifyPackagePath
        Get-MemoryCapabilities $MemoryConfigPath $Namespace
        Get-EditorCapabilities $ExtensionsPath
        Get-ManualCapabilities $EvidencePath
    )
    $availableTools = @($capabilities | Where-Object { $_.id -like 'host.*' -and $_.status -eq 'supported' } | ForEach-Object { 'mcp__codex_app__' + $_.id.Substring(5) })
    $hostStates = @{}
    foreach ($entry in $capabilities | Where-Object { $_.id -like 'host.*' }) { $hostStates[$entry.id] = $entry.status }
    [ordered]@{
        schemaVersion = 1
        observedAt = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        readOnly = $true
        capabilities = $capabilities
        # Direct projection into AgentKit #497's caller-supplied capabilities contract.
        # This authorizes no operation. Recheck host exposure before preparing a call.
        agentKitHost = @{ host = 'codex'; tools = $availableTools; evidence = 'Workspace report: operator evidence, recheck active session contracts; no action authorized.' }
        adapters = @(
            @{ operation = 'fork/attach/return'; adapter = 'AgentKit portable package'; status = 'supported'; requires = @(); evidence = 'AgentKit #495; works without optional integrations' }
            @{ operation = 'selected handoff'; adapter = 'AgentKit #497 create_thread'; status = $hostStates['host.create_thread']; requires = @('host.create_thread'); evidence = 'Selected attributed prompt; explicit new-chat authorization required' }
            @{ operation = 'full-history fork'; adapter = 'AgentKit #497 fork_thread'; status = $hostStates['host.fork_thread']; requires = @('host.fork_thread'); evidence = 'Explicit full-history authorization required; no selective native clone' }
            @{ operation = 'native return'; adapter = 'AgentKit #497 navigation'; status = $hostStates['host.navigate_to_codex_page']; requires = @('host.navigate_to_codex_page'); evidence = 'Navigate to saved parent; portable attach retains selected outcome; no automatic messaging' }
            @{ operation = 'memory extraction'; adapter = 'AgentKit #496 MemoryKit'; status = 'unknown'; requires = @('memorykit.configuration', 'memorykit.namespace'); evidence = 'Review and select candidates; configuration is not namespace access' }
            @{ operation = 'graph projection'; adapter = 'Workspace #57 follow-on'; status = 'unknown'; requires = @('context-graph.live', 'graphify.relationships', 'graphify.exclusions'); evidence = 'No graph adapter or new database created by this report' }
        )
    }
}

Export-ModuleMember -Function Get-ConversationCapabilityReport
