#Requires -Version 7.4
#Requires -Modules Pester
BeforeAll {
    $script:Entry = Join-Path $PSScriptRoot '../../scripts/Test-HookConfiguration.ps1'
    $script:Module = Join-Path $PSScriptRoot '../../scripts/modules/HookConfigurationAudit.psm1'
    Import-Module $Module -Force
    # macOS may put TestDrive below the /var symlink. Use its physical directory
    # for positive fixtures so the reader can continue rejecting linked parents.
    $script:FixtureRoot = $TestDrive
    for ($attempt = 0; $attempt -lt 64; $attempt++) {
        $link = $null
        for ($directory = [IO.DirectoryInfo]::new($script:FixtureRoot); $null -ne $directory; $directory = $directory.Parent) {
            if ($directory.LinkTarget) { $link = $directory; break }
        }
        if ($null -eq $link) { break }
        $suffix = [IO.Path]::GetRelativePath($link.FullName, $script:FixtureRoot)
        $script:FixtureRoot = Join-Path ($link.ResolveLinkTarget($true).FullName) $suffix
    }
    function Write-HookFixture {
        param([object]$Value, [string]$Name = 'hooks.json')
        $path = Join-Path $script:FixtureRoot $Name
        $Value | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $path -Encoding utf8
        $path
    }
    function Get-HookFixture {
        param([object[]]$Handlers = @(@{ type = 'command'; command = 'fixture-command' }))
        @{ hooks = @{ SessionStart = @(@{ hooks = $Handlers }) } }
    }
}

Describe 'Read-only hook configuration audit' {
    It 'resolves relative paths from the current PowerShell filesystem location' {
        $null = Write-HookFixture (Get-HookFixture)
        Push-Location $script:FixtureRoot
        try {
            $report = Invoke-HookConfigurationAudit -LiteralPath './hooks.json' -HostKind Claude
            $report.classification | Should -Be 'supported'
            $report.configurations[0].registrations.Count | Should -Be 1
        }
        finally { Pop-Location }
    }

    It 'inventories supported Claude exec form and optional metadata without projecting content' {
        $path = Write-HookFixture @{ permissions = @{ allow = @('secret-permission') }; disableAllHooks = $true
            hooks = @{ PreToolUse = @(@{ matcher = 'secret-matcher'; hooks = @(@{
                type = 'command'; command = 'secret-command'; args = @('secret-arg'); timeout = 1.5
                async = $false; statusMessage = 'secret-status'
            }) }) } }
        $report = Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude
        $report.classification | Should -Be 'supported'
        $report.execution | Should -Be 'not-evaluated'
        $report.configurations[0].disableAllHooks | Should -BeTrue
        $row = $report.configurations[0].registrations[0]
        $row.event | Should -Be 'PreToolUse'
        $row.argumentCount | Should -Be 1
        $row.timeout | Should -Be 1.5
        $row.async | Should -BeFalse
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-|hooks.json'
    }

    It 'supports Codex Windows command overrides without treating them as interchangeable' {
        $fixture = Get-HookFixture @(
            @{ type = 'command'; command = 'node hook'; commandWindows = 'pwsh hook'; additionalContextLimit = 0; timeout = 0; async = $true; statusMessage = '' }
            @{ type = 'command'; command = 'node hook'; commandWindows = 'pwsh OTHER'; additionalContextLimit = 0; timeout = 0; async = $true; statusMessage = '' }
        )
        $fixture.description = 'private-description'
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $fixture) -HostKind Codex
        $report.classification | Should -Be 'supported'
        $report.duplicates.Count | Should -Be 0
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'private-description|pwsh|node'
    }

    It 'detects identical registrations within and across sources independent of object key order' {
        $first = Write-HookFixture (Get-HookFixture @(
            @{ type = 'command'; command = 'same'; args = @('a', 'b'); timeout = 30 }
            @{ timeout = 30; args = @('a', 'b'); command = 'same'; type = 'command' }
        )) 'one.json'
        $second = Write-HookFixture (Get-HookFixture @(@{ command = 'same'; type = 'command'; args = @('a', 'b'); timeout = 30 })) 'two.json'
        $report = Invoke-HookConfigurationAudit -LiteralPath @($first, $second) -HostKind Claude
        $report.duplicates.Count | Should -Be 1
        $report.duplicates[0].reasonCode | Should -Be 'identical-registration-present'
        $report.duplicates[0].members.Count | Should -Be 3
        $report.duplicates[0].members.input | Should -Be @(1, 1, 2)
        $report.duplicates[0].members.hook | Should -Be @(1, 2, 1)
    }

    It 'includes each meaningful supported field and its presence in equality: <Field>' -ForEach @(
        @{ Field = 'command'; Value = 'Same' }
        @{ Field = 'args'; Value = @('b', 'a') }
        @{ Field = 'timeout'; Value = 31 }
        @{ Field = 'async'; Value = $true }
        @{ Field = 'statusMessage'; Value = 'other' }
        @{ Field = 'absence'; Value = $null }
    ) {
        $left = @{ type = 'command'; command = 'same'; args = @('a', 'b'); timeout = 30; async = $false; statusMessage = 'status' }
        $right = $left.Clone()
        if ($Field -eq 'absence') { $right.Remove('async') } else { $right[$Field] = $Value }
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture (Get-HookFixture @($left, $right))) -HostKind Claude
        $report.classification | Should -Be 'supported'
        $report.duplicates.Count | Should -Be 0
    }

    It 'keeps matcher values, matcher presence, events and whitespace distinct' {
        $handler = @{ type = 'command'; command = 'same' }
        $fixture = @{ hooks = @{
            SessionStart = @(@{ hooks = @($handler) }, @{ matcher = ''; hooks = @($handler) }, @{ matcher = '*'; hooks = @($handler) }, @{ matcher = '.*'; hooks = @($handler) }, @{ hooks = @(@{ type = 'command'; command = 'same ' }) })
            SessionEnd = @(@{ hooks = @($handler) })
        } }
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $fixture) -HostKind Claude
        $report.classification | Should -Be 'supported'
        $report.duplicates.Count | Should -Be 0
    }

    It 'retains supported siblings but never compares unknown handlers or groups' {
        $fixture = Get-HookFixture @(@{ type = 'command'; command = 'same' }, @{ type = 'command'; command = 'same'; env = @{ TOKEN = 'secret-value' } }, @{ type = 'http'; url = 'https://secret-value' })
        $fixture.hooks.SessionStart += @{ matcher = '*'; unknown = 'secret-value'; hooks = @(@{ type = 'command'; command = 'same' }) }
        $fixture.hooks.'secret-event' = @(@{ hooks = @(@{ type = 'command'; command = 'same' }) })
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $fixture) -HostKind Claude
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].registrations.Count | Should -Be 3
        $report.configurations[0].registrations[1].classification | Should -Be 'unverified'
        $report.duplicates.Count | Should -Be 0
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-'
    }

    It 'rejects malformed or unsupported metadata: <Label>' -ForEach @(
        @{ Label = 'timeout boolean'; Change = @{ timeout = $true } }
        @{ Label = 'timeout string'; Change = @{ timeout = '30' } }
        @{ Label = 'timeout null'; Change = @{ timeout = $null } }
        @{ Label = 'timeout negative'; Change = @{ timeout = -1 } }
        @{ Label = 'async string'; Change = @{ async = 'false' } }
        @{ Label = 'async null'; Change = @{ async = $null } }
        @{ Label = 'args scalar'; Change = @{ args = 'x' } }
        @{ Label = 'args null element'; Change = @{ args = @($null) } }
        @{ Label = 'command empty'; Change = @{ command = ' ' } }
        @{ Label = 'command numeric'; Change = @{ command = 1 } }
        @{ Label = 'type case'; Change = @{ type = 'Command' } }
        @{ Label = 'unknown key'; Change = @{ future = $true } }
        @{ Label = 'status null'; Change = @{ statusMessage = $null } }
        @{ Label = 'key case'; Change = @{ Timeout = 30 } }
        @{ Label = 'conditional'; Change = @{ if = 'Bash(*)' } }
        @{ Label = 'args too long'; Change = @{ args = @(1..257 | ForEach-Object { 'x' }) } }
        @{ Label = 'command too long'; Change = @{ command = ('x' * 8193) } }
    ) {
        $handler = [ordered]@{ type = 'command'; command = 'same' }
        foreach ($key in $Change.Keys) { $handler[$key] = $Change[$key] }
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture (Get-HookFixture @($handler, $handler))) -HostKind Claude
        $report.classification | Should -Be 'unverified'
        $report.duplicates.Count | Should -Be 0
    }

    It 'enforces Codex-specific input boundaries: <Label>' -ForEach @(
        @{ Label = 'Claude args'; Handler = @{ type = 'command'; command = 'same'; args = @() } }
        @{ Label = 'fractional seconds'; Handler = @{ type = 'command'; command = 'same'; timeout = 1.5 } }
        @{ Label = 'null Windows override'; Handler = @{ type = 'command'; command = 'same'; commandWindows = $null } }
        @{ Label = 'snake alias outside subset'; Handler = @{ type = 'command'; command = 'same'; command_windows = 'x' } }
        @{ Label = 'fractional context'; Handler = @{ type = 'command'; command = 'same'; additionalContextLimit = 1.5 } }
    ) {
        (Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture (Get-HookFixture @($Handler))) -HostKind Codex).classification | Should -Be 'unverified'
    }

    It 'does not confuse host-specific events' {
        $fixture = @{ hooks = @{ Interrupt = @(@{ hooks = @(@{ type = 'command'; command = 'x' }) }) } }
        $path = Write-HookFixture $fixture
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Codex).classification | Should -Be 'supported'
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude).classification | Should -Be 'unverified'
    }

    It 'accepts explicit empty hook containers but does not infer absent hooks' {
        (Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture @{ hooks = @{} }) -HostKind Claude).classification | Should -Be 'supported'
        (Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture @{}) -HostKind Claude).classification | Should -Be 'unverified'
    }

    It 'uses strict JSON, duplicate keys and UTF-8 checks: <Label>' -ForEach @(
        @{ Label = 'duplicate root'; Text = '{"hooks":{},"hooks":{}}' }
        @{ Label = 'duplicate nested'; Text = '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"a","command":"b"}]}]}}' }
        @{ Label = 'trailing comma'; Text = '{"hooks":{},}' }
        @{ Label = 'comment'; Text = '{/*secret-parser-value*/"hooks":{}}' }
        @{ Label = 'null hooks'; Text = '{"hooks":null}' }
        @{ Label = 'scalar root'; Text = 'false' }
        @{ Label = 'invalid switch'; Text = '{"hooks":{},"disableAllHooks":"false"}' }
        @{ Label = 'case changed hooks'; Text = '{"Hooks":{}}' }
        @{ Label = 'group null'; Text = '{"hooks":{"Stop":[null]}}' }
        @{ Label = 'non-array groups'; Text = '{"hooks":{"Stop":{}}}' }
    ) {
        $path = Join-Path $script:FixtureRoot 'malformed.json'
        Set-Content -LiteralPath $path -Value $Text -Encoding utf8
        $report = Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude
        $report.classification | Should -Be 'unverified'
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-parser-value|malformed.json'
    }

    It 'accepts JSONC comments, trailing commas and one UTF-8 BOM' {
        $path = Join-Path $script:FixtureRoot 'hooks.jsonc'
        [IO.File]::WriteAllText($path, '{/* comment */"hooks":{},}', [Text.UTF8Encoding]::new($true))
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Codex).classification | Should -Be 'supported'
    }

    It 'rejects invalid UTF-8, depth and file size limits without disclosing input' {
        $path = Join-Path $script:FixtureRoot 'bad.json'
        [IO.File]::WriteAllBytes($path, [byte[]]@(0xFF, 0xFF))
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude).classification | Should -Be 'unverified'
        Set-Content -LiteralPath $path -Value (('[' * 65) + '0' + (']' * 65))
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude).classification | Should -Be 'unverified'
        Set-Content -LiteralPath $path -Value ('x' * (2MB + 1))
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude).classification | Should -Be 'unverified'
    }

    It 'rejects over-limit containers and discards comparisons from a truncated file' {
        $handler = @{ type = 'command'; command = 'same' }
        $tooManyGroups = @{ hooks = @{ Stop = @(1..257 | ForEach-Object { @{ hooks = @($handler) } }) } }
        (Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $tooManyGroups) -HostKind Claude).classification | Should -Be 'unverified'
        $tooManyHandlers = @{ hooks = @{ Stop = @(@{ hooks = @(1..257 | ForEach-Object { $handler }) }) } }
        (Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $tooManyHandlers) -HostKind Claude).classification | Should -Be 'unverified'
        $overTotal = @{ hooks = @{ Stop = @(1..17 | ForEach-Object { @{ hooks = @(1..256 | ForEach-Object { $handler }) } }) } }
        $report = Invoke-HookConfigurationAudit -LiteralPath (Write-HookFixture $overTotal) -HostKind Claude
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].reasonCode | Should -Be 'registration-limit'
        $report.configurations[0].registrations.Count | Should -Be 0
        $report.duplicates.Count | Should -Be 0
    }

    It 'rejects linked parent directories instead of silently following another configuration source' {
        $directory = New-Item -ItemType Directory -Path (Join-Path $script:FixtureRoot 'real')
        $path = Write-HookFixture (Get-HookFixture) 'real/hooks.json'
        $linkPath = Join-Path $script:FixtureRoot 'linked'
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        $null = New-Item -ItemType $linkType -Path $linkPath -Target $directory.FullName
        $report = Invoke-HookConfigurationAudit -LiteralPath (Join-Path $linkPath 'hooks.json') -HostKind Claude
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].registrations.Count | Should -Be 0
        (Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Claude).classification | Should -Be 'supported'
    }

    It 'does not count the same file twice through relative or absolute aliases' {
        $path = Write-HookFixture (Get-HookFixture)
        $report = Invoke-HookConfigurationAudit -LiteralPath @($path, (Join-Path (Split-Path $path) './hooks.json')) -HostKind Claude
        $report.classification | Should -Be 'unverified'
        $report.configurations[1].reasonCode | Should -Be 'repeated-input'
        $report.duplicates.Count | Should -Be 0
    }

    It 'does not access URLs, UNC paths, providers, directories or unsupported formats' {
        $report = Invoke-HookConfigurationAudit -HostKind Codex -LiteralPath @('http://127.0.0.1:9/secret.json', '\\127.0.0.1\secret\hooks.json', 'Env:PATH', $script:FixtureRoot, (Join-Path $script:FixtureRoot 'config.toml'))
        $report.configurations.Count | Should -Be 5
        @($report.configurations | Where-Object classification -eq 'unverified').Count | Should -Be 5
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match '127.0.0.1|secret|PATH|toml'
    }

    It 'produces byte-stable JSON across repeated invocations and cultures' {
        $path = Write-HookFixture @{ hooks = @{ Stop = @(@{ hooks = @(@{ type = 'command'; command = 'same' }, @{ command = 'same'; type = 'command' }) }); SessionStart = @() } }
        $culture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR')
            $first = Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Codex | ConvertTo-Json -Depth 16
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
            $second = Invoke-HookConfigurationAudit -LiteralPath $path -HostKind Codex | ConvertTo-Json -Depth 16
            $first | Should -BeExactly $second
        }
        finally { [Threading.Thread]::CurrentThread.CurrentCulture = $culture }
    }

    It 'never executes commands or contacts endpoints and leaves both inputs unchanged' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $port = $listener.LocalEndpoint.Port
            $marker = Join-Path $script:FixtureRoot 'executed-secret.txt'
            $command = "Set-Content -LiteralPath '$marker' -Value executed; Invoke-WebRequest http://127.0.0.1:$port/secret-endpoint"
            $executable = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            $first = Write-HookFixture (Get-HookFixture @(@{ type = 'command'; command = $executable; args = @('-NoProfile', '-EncodedCommand', $encoded) })) 'secret-source.json'
            $second = Write-HookFixture (Get-HookFixture @(@{ type = 'command'; command = "`"$executable`" -NoProfile -EncodedCommand $encoded" })) 'other.json'
            $before = @($first, $second | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
            $json = & pwsh -NoProfile -File $Entry -HostKind Claude -LiteralPath $first -AsJson 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            ($json | ConvertFrom-Json).classification | Should -Be 'supported'
            $human = & pwsh -NoProfile -File $Entry -HostKind Codex -LiteralPath $second 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $json + $human | Should -Not -Match 'executed-secret|secret-endpoint|secret-source|127.0.0.1|Set-Content|Invoke-WebRequest'
            $json + $human | Should -Not -Match ([regex]::Escape($encoded))
            Test-Path -LiteralPath $marker | Should -BeFalse
            $listener.Pending() | Should -BeFalse
            @($first, $second | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash }) | Should -Be $before
        }
        finally { $listener.Stop() }
    }

    It 'returns CLI exit 1 for duplicates and unverified input, and 2 for invocation errors' {
        $duplicate = Write-HookFixture (Get-HookFixture @(@{ type = 'command'; command = 'x' }, @{ type = 'command'; command = 'x' }))
        $json = & pwsh -NoProfile -File $Entry -HostKind Codex -LiteralPath $duplicate -AsJson | Out-String
        $LASTEXITCODE | Should -Be 1
        ($json | ConvertFrom-Json).duplicates.Count | Should -Be 1
        $null = & pwsh -NoProfile -File $Entry -HostKind Codex -LiteralPath (Join-Path $script:FixtureRoot 'missing.json') -AsJson
        $LASTEXITCODE | Should -Be 1
        $json = & pwsh -NoProfile -File $Entry -HostKind 'private-invalid-host' -AsJson | Out-String
        $LASTEXITCODE | Should -Be 2
        $json | Should -Not -Match 'private-invalid-host'
        ($json | ConvertFrom-Json).reasonCode | Should -Be 'invalid-invocation'
        $null = & pwsh -NoProfile -File $Entry -HostKind Codex -AsJson
        $LASTEXITCODE | Should -Be 2
        $result = & $Entry -HostKind Codex -LiteralPath @(1..65 | ForEach-Object { 'missing.json' }) -AsJson | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 2
        $result.reasonCode | Should -Be 'invalid-invocation'
    }
}
