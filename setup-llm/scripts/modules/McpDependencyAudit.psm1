#Requires -Version 7.4
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'McpAuditToml.ps1')

function New-AuditDependency {
    param([string]$Kind, [string]$Selector, [string]$Classification, [string]$Reason)
    [pscustomobject][ordered]@{
        kind = $Kind; selector = $Selector; classification = $Classification; reasonCode = $Reason
    }
}

function Get-AuditClassification {
    param([object[]]$Dependencies)
    if (!$Dependencies.Count -or $Dependencies.classification -contains 'unverified') { return 'unverified' }
    if ($Dependencies.classification -contains 'mutable') { return 'mutable' }
    return 'exact-pin'
}

function Get-NpmSelectorAudit {
    param([string]$Selector)
    if ($Selector -match '^(?:\.{1,2}[/\\]|[/\\]|file:|link:|workspace:)') {
        return New-AuditDependency 'local' '[local package]' 'unverified' 'local-package-provenance-unknown'
    }
    # URLs are deliberately projected to fixed text: credentials, query strings and fragments
    # are never copied into the report. A full Git commit is identity, not provenance.
    if ($Selector -match '^(git\+https?|git\+ssh|git|https?|ssh)://|^(github|gitlab|bitbucket):|^[\w.-]+/[\w.-]+(?:#.*)?$') {
        $isGit = $Selector -match '^(git\+|git://|ssh://|github:|gitlab:|bitbucket:)|\.git(?:#|$)|^[\w.-]+/[\w.-]+(?:#.*)?$'
        if ($isGit) {
            $repository = '[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*'
            $validGit = $Selector -cmatch "^(?:(?:github|gitlab|bitbucket):)?$repository(?:#[^#\s]+)?`$"
            if (!$validGit) {
                $uri = $null
                $address = $Selector -creplace '^git\+', ''
                $validGit = [uri]::TryCreate($address, [UriKind]::Absolute, [ref]$uri) -and
                    $uri.Scheme -cin @('http', 'https', 'ssh', 'git') -and $uri.Host -and
                    $uri.AbsolutePath -cmatch '^/(?:[A-Za-z0-9._~-]+/)*[A-Za-z0-9_~-][A-Za-z0-9._~-]*$' -and
                    (!$uri.Fragment -or $uri.Fragment -cmatch '^#[^#\s]+$')
            }
            if (!$validGit) {
                return New-AuditDependency 'git' 'git:[redacted]' 'unverified' 'unsupported-git-repository'
            }
            if ($Selector -match '#(?<commit>[a-fA-F0-9]{40})$') {
                return New-AuditDependency 'git' "git:[redacted]#$($Matches.commit.ToLowerInvariant())" 'exact-pin' 'git-full-commit'
            }
            return New-AuditDependency 'git' 'git:[redacted]' 'mutable' 'git-ref-not-full-commit'
        }
        return New-AuditDependency 'remote' '[redacted URL]' 'unverified' 'remote-package-artifact'
    }
    if ($Selector -notmatch '^(?<name>@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*|[a-z0-9][a-z0-9._-]*)(?:@(?<version>[^\r\n]+))?$') {
        return New-AuditDependency 'npm' '[unrecognized selector]' 'unverified' 'unsupported-npm-selector'
    }
    $name = $Matches.name
    $version = $Matches['version']
    # Only SemVer's exact numeric core, optional prerelease and build metadata qualify.
    # npm also accepts aliases, paths and other syntaxes; those stay unverified.
    $number = '(?:0|[1-9][0-9]*)'
    $pre = '(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
    $semver = "^$number\.$number\.$number(?:-$pre(?:\.$pre)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?`$"
    if ($version -and $version -cmatch $semver) {
        return New-AuditDependency 'npm' "$name@$version" 'exact-pin' 'npm-exact-version'
    }
    if (!$version -or $version -match '^(?:[A-Za-z][A-Za-z0-9._-]*|[~^<>=*0-9v][0-9A-Za-z.*+~^<>=| -]*)$') {
        # Project the category, not arbitrary option-like text that could contain a secret.
        $display = if (!$version) { $name } else { "$name@[mutable]" }
        return New-AuditDependency 'npm' $display 'mutable' 'npm-unversioned-tag-or-range'
    }
    New-AuditDependency 'npm' "$name@[unrecognized]" 'unverified' 'unsupported-npm-version'
}

function Get-NpxAudit {
    param([string[]]$Arguments)
    $dependencies = [System.Collections.Generic.List[object]]::new()
    $packageFlags = $false
    $invalid = $false
    $index = 0
    while ($index -lt $Arguments.Count) {
        $arg = $Arguments[$index]
        if ($arg -cin @('-y', '--yes', '--no', '--ignore-scripts', '--offline')) { $index++; continue }
        if ($arg -cin @('-p', '--package')) {
            $packageFlags = $true
            $index++
            if ($index -ge $Arguments.Count -or [string]::IsNullOrWhiteSpace($Arguments[$index]) -or $Arguments[$index].StartsWith('-')) { $invalid = $true; break }
            $dependencies.Add((Get-NpmSelectorAudit $Arguments[$index]))
            $index++; continue
        }
        if ($arg -cmatch '^(?:--package=|-p=)(.+)$') {
            $packageFlags = $true
            $dependencies.Add((Get-NpmSelectorAudit $Matches[1]))
            $index++; continue
        }
        if ($arg -ceq '--') { $index++; break }
        if ($arg.StartsWith('-')) { $invalid = $true; break }
        break
    }
    # With explicit package flags the following token is the program to run, not a
    # dependency. Without them the first positional token is npx's package selector.
    if (!$invalid -and !$packageFlags) {
        if ($index -lt $Arguments.Count) { $dependencies.Add((Get-NpmSelectorAudit $Arguments[$index])) }
        else { $invalid = $true }
    }
    elseif (!$invalid -and ($index -ge $Arguments.Count -or [string]::IsNullOrWhiteSpace($Arguments[$index]) -or $Arguments[$index].StartsWith('-'))) { $invalid = $true }
    if ($invalid) {
        $dependencies.Add((New-AuditDependency 'npm' '[unresolved launch]' 'unverified' 'unsupported-npx-options-or-missing-command'))
    }
    $dependencies.ToArray()
}

function Get-DockerAudit {
    param([string[]]$Arguments)
    $unknown = { New-AuditDependency 'docker' '[unresolved image]' 'unverified' 'unsupported-docker-launch' }
    if (!$Arguments.Count -or $Arguments[0] -cne 'run') { return & $unknown }
    $index = 1
    while ($index -lt $Arguments.Count) {
        $arg = $Arguments[$index]
        if ($arg -cin @('--rm', '-i', '-t', '-it', '-ti', '--init')) { $index++; continue }
        if ($arg -cin @('-e', '--env', '--name', '--network', '-v', '--volume', '--mount', '-w', '--workdir', '-u', '--user', '--entrypoint', '--pull')) {
            $index += 2
            if ($index -gt $Arguments.Count -or !$Arguments[$index - 1] -or $Arguments[$index - 1].StartsWith('-')) { return & $unknown }
            continue
        }
        if ($arg -cmatch '^--(?:env|name|network|volume|mount|workdir|user|entrypoint|pull)=.+$') { $index++; continue }
        if ($arg -ceq '--') { $index++; break }
        if ($arg.StartsWith('-')) { return & $unknown }
        break
    }
    if ($index -ge $Arguments.Count) { return & $unknown }
    $image = $Arguments[$index]
    if ($image -cnotmatch '^(?:[a-z0-9][a-z0-9._-]*(?::[0-9]+)?/)*(?:[a-z0-9]+(?:[._-][a-z0-9]+)*)(?::[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?(?:@sha256:[a-fA-F0-9]{64})?$') { return & $unknown }
    if ($image -cmatch '@sha256:[a-fA-F0-9]{64}$') {
        return New-AuditDependency 'docker' $image 'exact-pin' 'docker-content-digest'
    }
    New-AuditDependency 'docker' $image 'mutable' 'docker-tag-or-implicit-latest'
}

function Test-McpAuditServerMetadata {
    param([System.Collections.IDictionary]$Server)
    if ($Server.Contains('enabled') -and $Server.enabled -isnot [bool]) { return $false }
    # Codex accepts the millisecond name as an alias. Do not infer precedence when
    # both spellings occur, even when their values appear equivalent.
    if ($Server.Contains('startup_timeout_sec') -and $Server.Contains('startup_timeout_ms')) { return $false }
    foreach ($field in @('startup_timeout_sec', 'startup_timeout_ms', 'tool_timeout_sec')) {
        if (!$Server.Contains($field)) { continue }
        $value = $Server[$field]
        # Only numeric types emitted by the JSON/TOML readers qualify. PowerShell
        # coercion would otherwise accept strings, booleans and null as numbers.
        if (($value -isnot [long] -and $value -isnot [int] -and $value -isnot [double]) -or
            ![double]::IsFinite([double]$value) -or $value -lt 0) { return $false }
    }
    return $true
}

function Get-McpServerAudit {
    param([string]$Name, [object]$Server, [int]$Index)
    $label = if ($Name -cmatch '^[A-Za-z][A-Za-z0-9_.-]{0,63}$') { $Name } else { "server-$Index" }
    $launchType = 'unknown'
    $dependencies = @()
    $references = @()
    $reason = 'unsupported-server-shape'
    $valid = $Server -is [System.Collections.IDictionary] -and
        $Server.Contains('command') -and $Server.command -is [string] -and $Server.command.Length -gt 0 -and
        (!$Server.Contains('type') -or $Server.type -ceq 'stdio') -and !$Server.Contains('url') -and
        (!$Server.Contains('env') -or ($Server.env -is [System.Collections.IDictionary] -and @($Server.env.Values | Where-Object { $_ -isnot [string] }).Count -eq 0)) -and
        @($Server.Keys | Where-Object { $_ -cnotmatch '\A(command|args|type|env|enabled|startup_timeout_sec|startup_timeout_ms|tool_timeout_sec)\z' }).Count -eq 0 -and
        (!$Server.Contains('args') -or ($Server.args -is [array] -and $Server.args.Count -le 256 -and @($Server.args | Where-Object { $_ -isnot [string] }).Count -eq 0))
    if ($valid -and !(Test-McpAuditServerMetadata $Server)) {
        $valid = $false
        $reason = 'invalid-server-metadata'
    }
    if ($valid) {
        $command = $Server.command
        [string[]]$arguments = @()
        if ($Server.Contains('args')) { $arguments = @($Server.args) }
        $tokens = @($command) + $arguments
        $references = @([regex]::Matches(($tokens -join "`n"), '\$\{(?<name>[A-Za-z_][A-Za-z0-9_]*)\}|\$(?<name>[A-Za-z_][A-Za-z0-9_]*)|%(?<name>[A-Za-z_][A-Za-z0-9_]*)%') |
            ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique -CaseSensitive)
        $base = ($command -split '[/\\]')[-1].ToLowerInvariant()
        $reason = 'unknown-local-executable'
        $launchType = 'local'
        # cmd's /c consumes shell syntax even when configuration supplies an argv array.
        # Accept only Workspace's tokenized /c npx form; metacharacters invalidate it.
        if ($base -in @('cmd', 'cmd.exe')) {
            $launchType = 'shell'
            if ($arguments.Count -ge 2 -and $arguments[0] -ieq '/c' -and
                $arguments[1] -cin @('npx', 'npx.cmd') -and ($arguments -join '') -notmatch '[&|<>^()%!"\r\n]') {
                $base = 'npx'
                [string[]]$arguments = @($arguments | Select-Object -Skip 2)
            }
            else { $reason = 'unsupported-shell-indirection' }
        }
        if ($base -in @('npx', 'npx.cmd', 'npx.exe')) {
            $launchType = 'npm'
            $dependencies = @(Get-NpxAudit $arguments)
        }
        elseif ($base -in @('docker', 'docker.exe')) {
            $launchType = 'docker'
            $dependencies = @(Get-DockerAudit $arguments)
        }
        elseif ($base -in @('sh', 'bash', 'zsh', 'pwsh', 'pwsh.exe', 'powershell', 'powershell.exe', 'cmd', 'cmd.exe')) {
            $launchType = 'shell'
            $reason = 'unsupported-shell-indirection'
            if (($tokens -join ' ') -match 'https?://') { $reason = 'remote-bootstrap-command' }
        }
        if ($references.Count -or @($tokens | Where-Object { $_.Length -gt 8192 -or $_ -match '[\x00\r\n]' }).Count) {
            $dependencies = @()
            $reason = if ($references.Count) { 'environment-reference-not-resolved' } else { 'unsupported-launch-token' }
        }
    }
    if (!$dependencies.Count) { $dependencies = @(New-AuditDependency $launchType '[not projected]' 'unverified' $reason) }
    $classification = Get-AuditClassification $dependencies
    $remediation = switch ($classification) {
        'exact-pin' { 'Review provenance and transitive dependencies separately; direct identity alone is not a trust or vulnerability verdict.' }
        'mutable' { 'Review the dependency and explicitly choose an exact version, full Git commit or Docker digest before changing configuration.' }
        default { 'Review the original configuration locally; use a documented launch form with explicit dependency identity.' }
    }
    [pscustomobject][ordered]@{
        server = $label; launchType = $launchType; classification = $classification
        dependencies = @($dependencies); environmentReferences = @($references); remediation = $remediation
    }
}

function Assert-AuditJsonKeys {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            if (!$keys.Add($property.Name)) { throw 'Duplicate JSON key.' }
            Assert-AuditJsonKeys $property.Value
        }
    }
    elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-AuditJsonKeys $item }
    }
}

function Invoke-McpDependencyAudit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$LiteralPath)
    $configurations = [System.Collections.Generic.List[object]]::new()
    $inputIndex = 0
    foreach ($path in $LiteralPath) {
        $inputIndex++
        $servers = @()
        $reason = 'unsupported-input-format'
        $classification = 'unverified'
        $document = $null
        try {
            # No provider evaluation, URL fetching, directory discovery or CLI exports.
            if ($path -match '^(?:[\\/]{2}|[A-Za-z][A-Za-z0-9+.-]*://)') { throw 'Local files only.' }
            $file = Get-Item -LiteralPath $path -ErrorAction Stop
            if ($file -isnot [System.IO.FileInfo] -or $file.Extension -cnotin @('.json', '.jsonc', '.toml')) { throw 'Unsupported file.' }
            $reason = 'unreadable-or-malformed-configuration'
            if ($file.Length -gt 2MB) { throw 'Input too large.' }
            $text = [System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($file.FullName)).TrimStart([char]0xFEFF)
            if ($file.Extension -ceq '.toml') {
                $config = ConvertFrom-McpAuditToml $text
                $serverKey = 'mcp_servers'
            }
            else {
                $options = [System.Text.Json.JsonDocumentOptions]::new()
                $options.MaxDepth = 64
                if ($file.Extension -ceq '.jsonc') {
                    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
                    $options.AllowTrailingCommas = $true
                }
                $document = [System.Text.Json.JsonDocument]::Parse($text, $options)
                Assert-AuditJsonKeys $document.RootElement
                $config = ConvertFrom-Json -InputObject $text -AsHashtable -Depth 64 -ErrorAction Stop
                $serverKey = 'mcpServers'
            }
            $reason = 'unsupported-configuration-shape'
            if ($config -isnot [System.Collections.IDictionary] -or !$config.Contains($serverKey) -or
                $config[$serverKey] -isnot [System.Collections.IDictionary] -or !$config[$serverKey].Count -or $config[$serverKey].Count -gt 512) { throw 'Unsupported shape.' }
            $serverIndex = 0
            $servers = @(foreach ($name in ($config[$serverKey].Keys | Sort-Object -CaseSensitive)) {
                $serverIndex++
                Get-McpServerAudit -Name $name -Server $config[$serverKey][$name] -Index $serverIndex
            })
            $classification = Get-AuditClassification $servers
            $reason = 'parsed'
        }
        catch {
            # Parser/file errors may embed source text or credentials. Never emit them.
            $servers = @()
            $classification = 'unverified'
        }
        finally { if ($null -ne $document) { $document.Dispose() } }
        $configurations.Add([pscustomobject][ordered]@{
            input = $inputIndex; classification = $classification; reasonCode = $reason; servers = @($servers)
        })
    }
    [pscustomobject][ordered]@{
        schemaVersion = 1; scope = 'direct-launch-selectors-only'
        classification = Get-AuditClassification $configurations.ToArray()
        configurations = @($configurations.ToArray())
    }
}

Export-ModuleMember -Function Invoke-McpDependencyAudit
