#Requires -Version 7.4
Set-StrictMode -Version Latest

function Assert-HookAuditJsonKey {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            if (!$keys.Add($property.Name)) { throw 'Duplicate JSON key.' }
            Assert-HookAuditJsonKey $property.Value
        }
    }
    elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-HookAuditJsonKey $item }
    }
}

function Test-HookAuditString {
    param([object]$Value, [switch]$NonEmpty)
    return $Value -is [string] -and $Value.Length -le 8192 -and
        $Value -notmatch '\x00' -and (!$NonEmpty -or ![string]::IsNullOrWhiteSpace($Value))
}

function Test-HookAuditHandler {
    param([object]$Handler, [string]$HostKind)
    if ($Handler -isnot [System.Collections.IDictionary]) { return $false }
    $allowed = if ($HostKind -ceq 'Claude') { @('type', 'command', 'args', 'timeout', 'async', 'statusMessage') }
        else { @('type', 'command', 'timeout', 'async', 'statusMessage', 'commandWindows', 'additionalContextLimit') }
    if (@($Handler.Keys | Where-Object { $_ -cnotin $allowed }).Count -or
        !$Handler.Contains('type') -or $Handler.type -isnot [string] -or $Handler.type -cne 'command' -or
        !$Handler.Contains('command') -or !(Test-HookAuditString $Handler.command -NonEmpty)) { return $false }
    foreach ($field in @('statusMessage', 'commandWindows')) {
        if ($Handler.Contains($field) -and !(Test-HookAuditString $Handler[$field])) { return $false }
    }
    if ($Handler.Contains('async') -and $Handler.async -isnot [bool]) { return $false }
    if ($Handler.Contains('args') -and ($Handler.args -isnot [array] -or $Handler.args.Count -gt 256 -or
        @($Handler.args | Where-Object { !(Test-HookAuditString $_) }).Count)) { return $false }
    foreach ($field in @('timeout', 'additionalContextLimit')) {
        if (!$Handler.Contains($field)) { continue }
        $value = $Handler[$field]
        if (($value -isnot [long] -and $value -isnot [int] -and $value -isnot [double]) -or
            ![double]::IsFinite([double]$value) -or $value -lt 0) { return $false }
        # Codex's pinned schema uses unsigned integers; Claude permits seconds as numbers.
        if (($HostKind -ceq 'Codex' -or $field -ceq 'additionalContextLimit') -and
            ($value -is [double])) { return $false }
    }
    return $true
}

function Read-HookAuditFile {
    param([string]$Path)
    # System.IO avoids PowerShell providers/wildcards. Reject remote paths and links
    # before opening; no configuration-provided path or command is ever followed.
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '^(?:[\\/]{2}|[A-Za-z][A-Za-z0-9+.-]*://)') { throw 'Local files only.' }
    $fullPath = [System.IO.Path]::GetFullPath($Path, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath)
    if ($fullPath -match '^[\\/]{2}' -or [System.IO.Path]::GetExtension($fullPath) -cnotin @('.json', '.jsonc')) { throw 'Unsupported file.' }
    $file = [System.IO.FileInfo]::new($fullPath)
    if (!$file.Exists -or $file.Length -gt 2MB) { throw 'Unreadable or oversized input.' }
    if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Links are unsupported.' }
    for ($item = $file.Directory; $null -ne $item; $item = $item.Parent) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Links are unsupported.' }
    }
    if ($IsWindows) {
        $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($fullPath))
        if ($drive.DriveType -eq [System.IO.DriveType]::Network) { throw 'Network drive unsupported.' }
    }
    $stream = [System.IO.File]::OpenRead($fullPath)
    try {
        $buffer = [byte[]]::new(2MB + 1)
        $length = 0
        while ($length -lt $buffer.Length) {
            $read = $stream.Read($buffer, $length, $buffer.Length - $length)
            if (!$read) { break }
            $length += $read
        }
        if ($length -gt 2MB) { throw 'Input grew beyond limit.' }
        $content = [System.Text.UTF8Encoding]::new($false, $true).GetString($buffer, 0, $length)
        if ($content.Length -and $content[0] -ceq [char]0xFEFF) { $content = $content.Substring(1) }
        [pscustomobject]@{ Path = $fullPath; Text = $content; Jsonc = $file.Extension -ceq '.jsonc' }
    }
    finally { $stream.Dispose() }
}

function Invoke-HookConfigurationAudit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateCount(1, 64)][string[]]$LiteralPath, [Parameter(Mandatory)][ValidateSet('Claude', 'Codex')][string]$HostKind)
    $HostKind = if ($HostKind -ieq 'Claude') { 'Claude' } else { 'Codex' }
    $events = @('SessionStart', 'SessionEnd', 'UserPromptSubmit', 'PreToolUse', 'PermissionRequest',
        'PostToolUse', 'PreCompact', 'PostCompact', 'SubagentStart', 'SubagentStop', 'Stop')
    $events += if ($HostKind -ceq 'Claude') { @('PostToolUseFailure', 'Notification', 'StopFailure', 'Setup') }
        else { @('PreModelRequest', 'PostModelRequest', 'Interrupt') }
    $configurations = [System.Collections.Generic.List[object]]::new()
    # Raw identities are held only for this invocation. No command hashes are projected:
    # hashes of short secrets can disclose them through dictionary attacks.
    $identities = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::Ordinal)
    $identityOrder = [System.Collections.Generic.List[string]]::new()
    $pathComparer = if ($IsWindows) { [System.StringComparer]::OrdinalIgnoreCase } else { [System.StringComparer]::Ordinal }
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new($pathComparer)
    $inputIndex = 0
    $registrationCount = 0
    foreach ($path in $LiteralPath) {
        $inputIndex++
        $registrations = [System.Collections.Generic.List[object]]::new()
        $pending = [System.Collections.Generic.List[object]]::new()
        $reason = 'unreadable-or-malformed-configuration'
        $classification = 'unverified'
        $disableAllHooks = $null
        $document = $null
        try {
            $source = Read-HookAuditFile $path
            $reason = 'repeated-input'
            if (!$seenPaths.Add($source.Path)) { throw 'Repeated input.' }
            $reason = 'unreadable-or-malformed-configuration'
            $options = [System.Text.Json.JsonDocumentOptions]::new()
            $options.MaxDepth = 64
            $options.CommentHandling = if ($source.Jsonc) { [System.Text.Json.JsonCommentHandling]::Skip } else { [System.Text.Json.JsonCommentHandling]::Disallow }
            $options.AllowTrailingCommas = $source.Jsonc
            $document = [System.Text.Json.JsonDocument]::Parse($source.Text, $options)
            Assert-HookAuditJsonKey $document.RootElement
            $config = ConvertFrom-Json -InputObject $source.Text -AsHashtable -Depth 64 -ErrorAction Stop
            $reason = 'unsupported-configuration-shape'
            if ($config -isnot [System.Collections.IDictionary] -or !$config.Contains('hooks') -or
                $config.hooks -isnot [System.Collections.IDictionary] -or $config.hooks.Count -gt 64) { throw 'Unsupported hooks container.' }
            if ($HostKind -ceq 'Codex' -and (@($config.Keys | Where-Object { $_ -cnotin @('description', 'hooks') }).Count -or
                ($config.Contains('description') -and !(Test-HookAuditString $config.description)))) { throw 'Unsupported hook file.' }
            if ($HostKind -ceq 'Claude' -and $config.Contains('disableAllHooks')) {
                if ($config.disableAllHooks -isnot [bool]) { throw 'Invalid global switch.' }
                $disableAllHooks = $config.disableAllHooks
            }
            $classification = 'supported'
            $reason = 'parsed'
            # Ordinal ordering is independent of the machine's culture.
            [string[]]$eventNames = @($config.hooks.Keys)
            [Array]::Sort($eventNames, [System.StringComparer]::Ordinal)
            foreach ($hookEvent in $eventNames) {
                if ($hookEvent -cnotin $events -or $config.hooks[$hookEvent] -isnot [array] -or $config.hooks[$hookEvent].Count -gt 256) {
                    $classification = 'unverified'; $reason = 'unsupported-event-or-groups'; continue
                }
                $groupIndex = 0
                foreach ($group in $config.hooks[$hookEvent]) {
                    $groupIndex++
                    if ($group -isnot [System.Collections.IDictionary] -or
                        @($group.Keys | Where-Object { $_ -cnotin @('matcher', 'hooks') }).Count -or
                        !$group.Contains('hooks') -or $group.hooks -isnot [array] -or $group.hooks.Count -gt 256 -or
                        ($group.Contains('matcher') -and !(Test-HookAuditString $group.matcher))) {
                        $classification = 'unverified'; $reason = 'unsupported-group'; continue
                    }
                    $hookIndex = 0
                    foreach ($handler in $group.hooks) {
                        $hookIndex++
                        $registrationCount++
                        if ($registrationCount -gt 4096) { $reason = 'registration-limit'; throw 'Registration limit.' }
                        $supported = Test-HookAuditHandler $handler $HostKind
                        $row = [pscustomobject][ordered]@{
                            event = $hookEvent; group = $groupIndex; hook = $hookIndex
                            classification = if ($supported) { 'supported' } else { 'unverified' }
                            reasonCode = if ($supported) { 'command-registration' } else { 'unsupported-handler' }
                            matcherPresent = $group.Contains('matcher')
                            argumentCount = if ($supported -and $handler.Contains('args')) { $handler.args.Count } else { $null }
                            timeout = if ($supported -and $handler.Contains('timeout')) { $handler.timeout } else { $null }
                            async = if ($supported -and $handler.Contains('async')) { $handler.async } else { $null }
                        }
                        $registrations.Add($row)
                        if (!$supported) { $classification = 'unverified'; $reason = 'unsupported-handler'; continue }
                        $identity = [ordered]@{ event = $hookEvent }
                        if ($group.Contains('matcher')) { $identity.matcher = $group.matcher }
                        foreach ($key in @('type', 'command', 'args', 'timeout', 'async', 'statusMessage', 'commandWindows', 'additionalContextLimit')) {
                            if ($handler.Contains($key)) { $identity[$key] = $handler[$key] }
                        }
                        $pending.Add([pscustomobject]@{ Key = ($identity | ConvertTo-Json -Compress -Depth 8); Member = [pscustomobject][ordered]@{ input = $inputIndex; event = $hookEvent; group = $groupIndex; hook = $hookIndex } })
                    }
                }
            }
            foreach ($entry in $pending) {
                if (!$identities.ContainsKey($entry.Key)) {
                    $identities.Add($entry.Key, [System.Collections.Generic.List[object]]::new())
                    $identityOrder.Add($entry.Key)
                }
                $identities[$entry.Key].Add($entry.Member)
            }
        }
        catch {
            # File/parser errors may contain paths, commands or credentials.
            $classification = 'unverified'
            $registrations.Clear()
            $disableAllHooks = $null
        }
        finally { if ($null -ne $document) { $document.Dispose() } }
        $configurations.Add([pscustomobject][ordered]@{
            input = $inputIndex; classification = $classification; reasonCode = $reason
            disableAllHooks = $disableAllHooks; registrations = @($registrations.ToArray())
        })
    }
    $duplicates = [System.Collections.Generic.List[object]]::new()
    # Explicit insertion order follows ordinal event/input order; never expose keys.
    foreach ($identityKey in $identityOrder) {
        $members = $identities[$identityKey]
        if ($members.Count -lt 2) { continue }
        $duplicates.Add([pscustomobject][ordered]@{
            id = $duplicates.Count + 1; reasonCode = 'identical-registration-present'
            members = @($members.ToArray())
        })
    }
    [pscustomobject][ordered]@{
        schemaVersion = 1; scope = 'selected-hook-registrations-only'; hostKind = $HostKind
        classification = if (!$configurations.Count -or @($configurations | Where-Object classification -eq 'unverified').Count) { 'unverified' } else { 'supported' }
        execution = 'not-evaluated'; configurations = @($configurations.ToArray()); duplicates = @($duplicates.ToArray())
    }
}

Export-ModuleMember -Function Invoke-HookConfigurationAudit
