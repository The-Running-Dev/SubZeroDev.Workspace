#Requires -Version 7.4
#Requires -Modules Pester
BeforeAll {
    $script:Entry = Join-Path $PSScriptRoot '../../scripts/Test-McpDependencies.ps1'
    $script:Module = Join-Path $PSScriptRoot '../../scripts/modules/McpDependencyAudit.psm1'
    Import-Module $Module -Force
    function Get-ConfigReport {
        param([string]$Text, [string]$Extension = 'json')
        $path = Join-Path $TestDrive "config.$Extension"
        [IO.File]::WriteAllText($path, $Text)
        Invoke-McpDependencyAudit -LiteralPath $path
    }
    function Get-ServerReport {
        param([object]$Server)
        (Get-ConfigReport (@{ mcpServers = @{ fixture = $Server } } | ConvertTo-Json -Depth 20)).configurations[0].servers[0]
    }
}
Describe 'MCP launch selector classification' {
    It 'distinguishes the existing memory launch from exact pins, including Windows wrappers and paths with spaces' {
        $path = Join-Path $PSScriptRoot 'fixtures/mcp-dependencies/memory.json'
        $hash = (Get-FileHash -LiteralPath $path).Hash
        $report = Invoke-McpDependencyAudit -LiteralPath $path
        $report.classification | Should -Be 'mutable'
        foreach ($server in $report.configurations[0].servers) {
            $expected = if ($server.server.StartsWith('memory')) { 'mutable' } else { 'exact-pin' }
            $server.classification | Should -Be $expected
        }
        $report.configurations[0].servers.Count | Should -Be 5
        (Get-FileHash -LiteralPath $path).Hash | Should -Be $hash
    }
    It 'classifies npm selector <Selector> as <Expected>' -ForEach @(
        @{ Selector = 'server'; Expected = 'mutable' }
        @{ Selector = '@scope/server'; Expected = 'mutable' }
        @{ Selector = 'server@latest'; Expected = 'mutable' }
        @{ Selector = 'server@^1.2.3'; Expected = 'mutable' }
        @{ Selector = 'server@~1.2.3'; Expected = 'mutable' }
        @{ Selector = 'server@1.x'; Expected = 'mutable' }
        @{ Selector = 'server@>=1.2.3 <2'; Expected = 'mutable' }
        @{ Selector = 'server@01.2.3'; Expected = 'mutable' }
        @{ Selector = 'server@1.2.3'; Expected = 'exact-pin' }
        @{ Selector = '@scope/server@0.1.0-rc.1+build.3'; Expected = 'exact-pin' }
        @{ Selector = 'server@npm:other@1.2.3'; Expected = 'unverified' }
        @{ Selector = './local-package'; Expected = 'unverified' }
        @{ Selector = 'https://user:secret@example.invalid/package.tgz?token=secret'; Expected = 'unverified' }
        @{ Selector = 'git+https://user:secret@example.invalid/server.git#main'; Expected = 'mutable' }
        @{ Selector = 'github:owner/repo#v1.0'; Expected = 'mutable' }
        @{ Selector = 'owner/repo#0123456789abcdef0123456789abcdef01234567'; Expected = 'exact-pin' }
    ) {
        (Get-ServerReport @{ command = 'npx'; args = @('-y', $Selector) }).classification | Should -Be $Expected
    }
    It 'rejects malformed Git repositories before considering a full commit' -ForEach @(
        @{ Repository = 'github:' }
        @{ Repository = 'github:owner/' }
        @{ Repository = 'github:/repo' }
        @{ Repository = 'git+https://' }
        @{ Repository = 'git+https://example.invalid' }
        @{ Repository = 'git+https:///repo.git' }
        @{ Repository = 'git+https://example.invalid/repo.git#main' }
    ) {
        $selector = $Repository + '#0123456789abcdef0123456789abcdef01234567'
        $server = Get-ServerReport @{ command = 'npx'; args = @($selector) }
        $server.classification | Should -Be 'unverified'
        $server.dependencies[0].selector | Should -Be 'git:[redacted]'
    }
    It 'recognizes a structured Git URL and reveals only its full commit' {
        $commit = '0123456789abcdef0123456789abcdef01234567'
        $server = Get-ServerReport @{ command = 'npx'; args = @("git+https://git-user:git-secret@example.invalid/owner/repo.git?token=query-secret#$commit") }
        $server.classification | Should -Be 'exact-pin'
        $server.dependencies[0].selector | Should -Be "git:[redacted]#$commit"
        ($server | ConvertTo-Json -Depth 12) | Should -Not -Match 'git-user|git-secret|query-secret|example.invalid'
    }
    It 'includes every package flag and propagates mutable dependencies without echoing command arguments' {
        $server = Get-ServerReport @{ command = 'npx'; args = @('-y', '--package=@scope/one@1.2.3', '-p', 'two@latest', '--package', 'three@2.0.0', '--', 'server-bin', '--token', 'fixture-secret') }
        $server.dependencies.Count | Should -Be 3
        $server.classification | Should -Be 'mutable'
        $server.dependencies[1].selector | Should -Be 'two@[mutable]'
        ($server | ConvertTo-Json -Depth 12) | Should -Not -Match 'fixture-secret'
    }
    It 'leaves unknown flags and missing package commands unverified' -ForEach @(
        @{ Arguments = @('--registry', 'private-secret', 'server@1.2.3') }
        @{ Arguments = @('--package') }
        @{ Arguments = @('--package=server@1.2.3') }
        @{ Arguments = @('--package=server@1.2.3', '') }
        @{ Arguments = @('--package=server@1.2.3', '   ') }
        @{ Arguments = @('--package=server@1.2.3', '--unknown', 'private-secret') }
        @{ Arguments = @() }
        @{ Arguments = @('-c', 'npx server@1.2.3') }
    ) {
        (Get-ServerReport @{ command = 'npx'; args = $Arguments }).classification | Should -Be 'unverified'
    }
    It 'distinguishes Docker tags and digests and ignores secret option values' {
        (Get-ServerReport @{ command = 'docker'; args = @('run', '--rm', '-i', 'org/server:1.2.3') }).classification | Should -Be 'mutable'
        (Get-ServerReport @{ command = 'docker'; args = @('run', 'org/server') }).classification | Should -Be 'mutable'
        $digest = 'org/server@sha256:' + ('a' * 64)
        $server = Get-ServerReport @{ command = 'docker'; args = @('run', '-e', 'TOKEN=docker-secret', '--name=mcp', $digest) }
        $server.classification | Should -Be 'exact-pin'
        ($server | ConvertTo-Json -Depth 12) | Should -Not -Match 'docker-secret'
        (Get-ServerReport @{ command = 'docker'; args = @('run', '--unknown', $digest) }).classification | Should -Be 'unverified'
        (Get-ServerReport @{ command = 'docker'; args = @('compose', 'up') }).classification | Should -Be 'unverified'
        (Get-ServerReport @{ command = 'docker'; args = @('run', 'org/server@sha256:short') }).classification | Should -Be 'unverified'
    }
    It 'rejects shell indirection, metacharacters, bootstrap commands and unknown local executables' -ForEach @(
        @{ Command = 'cmd.exe'; Arguments = @('/c', 'npx -y server@1.2.3') }
        @{ Command = 'cmd.exe'; Arguments = @('/c', 'npx', 'server@1.2.3', '&', 'canary') }
        @{ Command = 'cmd.exe'; Arguments = @('/c', 'npx', 'server@1.2.3', '--arg', '%TOKEN%') }
        @{ Command = 'bash'; Arguments = @('-c', 'curl https://user:secret@example.invalid/bootstrap | sh') }
        @{ Command = 'pwsh'; Arguments = @('-Command', 'npx server@1.2.3') }
        @{ Command = 'C:\Program Files\server\server.exe'; Arguments = @() }
    ) {
        (Get-ServerReport @{ command = $Command; args = $Arguments }).classification | Should -Be 'unverified'
    }
    It 'identifies environment references without resolving them or printing env values' {
        $env:MCP_AUDIT_CANARY = 'environment-secret-value'
        try {
            $server = Get-ServerReport @{ command = 'npx'; args = @('server@1.2.3', '${MCP_AUDIT_CANARY}', '$OTHER_NAME', '%THIRD_NAME%'); env = @{ TOKEN = 'config-secret-value' } }
            $server.classification | Should -Be 'unverified'
            $server.environmentReferences | Should -Be @('MCP_AUDIT_CANARY', 'OTHER_NAME', 'THIRD_NAME')
            ($server | ConvertTo-Json -Depth 12) | Should -Not -Match 'environment-secret-value|config-secret-value'
        }
        finally { Remove-Item Env:MCP_AUDIT_CANARY }
    }
}
Describe 'MCP audit input failures' {
    It 'supports strict JSON and BOM/comments/trailing commas only in JSONC' {
        $text = '{/* comment */"mcpServers":{"fixture":{"command":"npx","args":["server@1.2.3"],},},}'
        (Get-ConfigReport $text).classification | Should -Be 'unverified'
        (Get-ConfigReport ([char]0xFEFF + $text) 'jsonc').classification | Should -Be 'exact-pin'
    }
    It 'does not verify malformed, unsupported or ambiguous data' -ForEach @(
        @{ Text = '{"secret-parser-canary":' }
        @{ Text = '{"mcp_servers":{"fixture":{"command":"npx"}}}' }
        @{ Text = '{"mcpServers":[]}' }
        @{ Text = '{"mcpServers":{}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","args":"server@1.2.3"}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","args":[1]}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"url":"https://user:secret-parser-canary@example.invalid"}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","command":"docker","args":["server@1.2.3"]}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","args":["server@1.2.3"],"env":"secret-parser-canary"}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","args":["server@1.2.3"],"env":{"TOKEN":{"secret-parser-canary":1}}}}}' }
        @{ Text = '{"mcpServers":{"fixture":{"command":"npx","args":["server@1.2.3"],"unsupportedLauncherOption":true}}}' }
        @{ Text = '{"mcpServers":{"fixture":null}}' }
    ) {
        $report = Get-ConfigReport $Text
        $report.classification | Should -Be 'unverified'
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-parser-canary'
    }
    It 'rejects unsupported formats, unreadable paths, invalid UTF-8 and oversized files' {
        $toml = Join-Path $TestDrive 'config.toml'
        [IO.File]::WriteAllText($toml, '[mcp_servers.fixture]')
        $bad = Join-Path $TestDrive 'invalid.json'
        [IO.File]::WriteAllBytes($bad, [byte[]]@(0xFF, 0xFF))
        $large = Join-Path $TestDrive 'large.json'
        [IO.File]::WriteAllText($large, (' ' * (2MB + 1)))
        $report = Invoke-McpDependencyAudit -LiteralPath @($toml, $bad, $large, (Join-Path $TestDrive 'missing.json'), 'https://user:secret@example.invalid/config.json')
        $report.configurations.Count | Should -Be 5
        @($report.configurations | Where-Object classification -NE unverified).Count | Should -Be 0
    }
}
Describe 'Native Codex TOML input' {
    It 'matches JSON classification for <Command> <Selector>' -ForEach @(
        @{ Command = 'npx'; Prefix = ''; Selector = 'server@1.2.3' }
        @{ Command = 'npx'; Prefix = ''; Selector = '@scope/server@latest' }
        @{ Command = 'npx'; Prefix = ''; Selector = 'github:owner/repo#0123456789abcdef0123456789abcdef01234567' }
        @{ Command = 'npx'; Prefix = ''; Selector = 'github:owner/repo#main' }
        @{ Command = 'docker'; Prefix = '"run", '; Selector = ('image@sha256:' + ('a' * 64)) }
        @{ Command = 'docker'; Prefix = '"run", '; Selector = 'image:latest' }
        @{ Command = 'local-server'; Prefix = ''; Selector = 'argument-secret' }
    ) {
        $toml = "[mcp_servers.fixture]`ncommand = `"$Command`"`nargs = [$Prefix`"$Selector`"]"
        $jsonArgs = @(if ($Prefix) { 'run'; $Selector } else { $Selector })
        $expected = Get-ServerReport @{ command = $Command; args = $jsonArgs }
        $actual = (Get-ConfigReport $toml 'toml').configurations[0].servers[0]
        ($actual | ConvertTo-Json -Depth 12 -Compress) | Should -Be ($expected | ConvertTo-Json -Depth 12 -Compress)
    }
    It 'parses quoted keys, literal Windows paths, escaped basic strings, comments and multiline arrays' {
        $toml = @'
model = "example"
[features]
example = true
[mcp_servers."quoted.name"] # a dot inside a quoted key is not a path separator
command = 'C:\Program Files\nodejs\npx.cmd'
args = [
  "-y", # preserve array order
  "server\u00401.2.3",
  "hash#value", "quote\"value", "back\\slash", "brackets[]{}", "",
]
[mcp_servers.'quoted.name'.env]
TOKEN = "redaction-canary"
[mcp_servers.escaped]
command = "C:\\Program Files\\nodejs\\npx.cmd"
args = ['server@1.2.3']
'@
        $report = Get-ConfigReport ([char]0xFEFF + $toml.Replace("`n", "`r`n")) 'toml'
        $report.classification | Should -Be 'exact-pin'
        $report.configurations[0].servers.server | Should -Be @('escaped', 'quoted.name')
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'redaction-canary|Program Files|hash#value'
    }
    It 'accepts dotted assignments and inline tables without conflating case or quoted dots' {
        $toml = @'
mcp_servers.Fixture = { command = 'npx', args = ['server@1.2.3'], env = { TOKEN = 'secret-canary' } }
mcp_servers.fixture.command = 'npx'
mcp_servers.fixture.args = ['server@latest']
mcp_servers."fixture.dot".command = 'npx'
mcp_servers."fixture.dot".args = ['server@2.0.0']
'@
        $report = Get-ConfigReport $toml 'toml'
        $report.classification | Should -Be 'mutable'
        $report.configurations[0].servers.Count | Should -Be 3
        @($report.configurations[0].servers | Where-Object classification -EQ 'exact-pin').Count | Should -Be 2
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-canary'
    }
    It 'requires exact server-field names, without cultural string aliases' {
        foreach ($key in @('Command', ('env' + [char]0x00AD), "args`n")) {
            $server = [ordered]@{ command = 'npx'; args = @('server@1.2.3') }
            $server[$key] = 'secret-canary'
            (Get-ServerReport $server).classification | Should -Be 'unverified'
            $quotedKey = ConvertTo-Json -InputObject $key -Compress
            $toml = "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']`n$quotedKey = 'secret-canary'"
            (Get-ConfigReport $toml 'toml').classification | Should -Be 'unverified'
        }
    }
    It 'enumerates every server, including HTTP, local, disabled and unknown options' {
        $toml = @'
[mcp_servers.pinned]
command = 'npx'
args = ['server@1.2.3']
[mcp_servers.http]
url = 'https://user:secret-canary@example.invalid?token=secret-canary'
[mcp_servers.local]
command = 'C:\server\server.exe'
[mcp_servers.disabled]
command = 'npx'
args = ['server@1.2.3']
enabled = false
[mcp_servers.future]
command = 'npx'
args = ['server@1.2.3']
future_option = true
[mcp_servers.environment]
command = 'npx'
args = ['server@1.2.3', '${MCP_AUDIT_CANARY}']
env = { TOKEN = 'secret-canary' }
[mcp_servers.timeout]
command = 'npx'
args = ['server@1.2.3']
startup_timeout_sec = 10.5
'@
        $report = Get-ConfigReport $toml 'toml'
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].reasonCode | Should -Be 'parsed'
        $report.configurations[0].servers.Count | Should -Be 7
        @($report.configurations[0].servers | Where-Object classification -EQ 'unverified').Count | Should -Be 6
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-canary|server.exe'
        ($report.configurations[0].servers | Where-Object server -EQ 'environment').environmentReferences | Should -Be @('MCP_AUDIT_CANARY')
    }
    It 'fails the whole input closed for <Label>' -ForEach @(
        @{ Label = 'duplicate key'; Tail = "command = 'docker'" }
        @{ Label = 'duplicate table'; Tail = '[mcp_servers.fixture]' }
        @{ Label = 'duplicate quoted key'; Tail = '"command" = "docker"' }
        @{ Label = 'duplicate Unicode key'; Tail = '"comm\u0061nd" = "docker"' }
        @{ Label = 'inline table mutation'; Tail = "env = { TOKEN = 'secret-canary' }`nenv.OTHER = 'x'" }
        @{ Label = 'inline table redefinition'; Tail = "env = { TOKEN = 'secret-canary' }`n[mcp_servers.fixture.env]" }
        @{ Label = 'inline duplicate key'; Tail = "env = { TOKEN = 'secret-canary', TOKEN = 'x' }" }
        @{ Label = 'inline trailing comma'; Tail = "env = { TOKEN = 'secret-canary', }" }
        @{ Label = 'dotted inline key'; Tail = "env = { TOKEN.part = 'secret-canary' }" }
        @{ Label = 'array of tables'; Tail = '[[mcp_servers.other]]' }
        @{ Label = 'table versus scalar'; Tail = "[mcp_servers.fixture.command]" }
        @{ Label = 'explicit namespace via dotted assignment'; Tail = "[other.child]`nx = 1`n[other]`nchild.y = 2" }
        @{ Label = 'implicit namespace via dotted assignment'; Tail = "[other.child.leaf]`nx = 1`n[other]`nchild.y = 2" }
        @{ Label = 'dotted namespace via header'; Tail = "other.child = 1`n[mcp_servers.fixture.other]" }
        @{ Label = 'missing equals'; Tail = "secret-canary 'value'" }
        @{ Label = 'unclosed array'; Tail = "other = ['secret-canary'" }
        @{ Label = 'missing array separator'; Tail = "other = ['secret-canary' 'value']" }
        @{ Label = 'invalid escape'; Tail = 'other = "secret-canary\q"' }
        @{ Label = 'Unicode surrogate'; Tail = 'other = "\uD800"' }
        @{ Label = 'Unicode overflow'; Tail = 'other = "\U00110000"' }
        @{ Label = 'unterminated string'; Tail = 'other = "secret-canary' }
        @{ Label = 'multiline string'; Tail = 'other = """secret-canary"""' }
        @{ Label = 'bare string'; Tail = 'other = secret-canary' }
        @{ Label = 'date'; Tail = 'other = 2026-10-28' }
        @{ Label = 'hex integer'; Tail = 'other = 0xFF' }
        @{ Label = 'leading zero'; Tail = 'other = 01' }
        @{ Label = 'integer overflow'; Tail = 'other = 9223372036854775808' }
        @{ Label = 'uppercase boolean'; Tail = 'other = True' }
        @{ Label = 'trailing data'; Tail = "other = true secret-canary" }
        @{ Label = 'unicode indentation'; Tail = ([char]0x3000 + 'other = 1') }
        @{ Label = 'unicode array space'; Tail = ('other = [1,' + [char]0x3000 + '2]') }
        @{ Label = 'ignorable boolean character'; Tail = ('other = t' + [char]0x00AD + 'rue') }
        @{ Label = 'complexity'; Tail = ('other = ' + ('[' * 66) + '0' + (']' * 66)) }
        @{ Label = 'combined table and value depth'; Tail = ('[' + ((1..60 | ForEach-Object { 'a' }) -join '.') + "]`nvalue = [[[[0]]]]") }
    ) {
        $toml = "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']`n$Tail"
        $report = Get-ConfigReport $toml 'toml'
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].servers.Count | Should -Be 0
        ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'secret-canary'
    }
    It 'rejects malformed or unsupported data before and after otherwise pinned MCP entries' {
        foreach ($bad in @('instructions = """secret-canary"""', 'bad = secret-canary')) {
            foreach ($toml in @("$bad`n[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']", "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']`n[unrelated]`n$bad")) {
                $report = Get-ConfigReport $toml 'toml'
                $report.classification | Should -Be 'unverified'
                $report.configurations[0].servers.Count | Should -Be 0
            }
        }
    }
    It 'enforces server, table-depth, UTF-8 and file-size limits for TOML too' {
        $servers = (0..512 | ForEach-Object { "[mcp_servers.s$_]`ncommand = 'npx'`nargs = ['server@1.2.3']" }) -join "`n"
        (Get-ConfigReport $servers 'toml').classification | Should -Be 'unverified'
        (Get-ConfigReport ('[' + ((1..65 | ForEach-Object { 'a' }) -join '.') + ']') 'toml').classification | Should -Be 'unverified'
        (Get-ConfigReport (' ' * (2MB + 1)) 'toml').classification | Should -Be 'unverified'
        $bad = Join-Path $TestDrive 'invalid.toml'
        [IO.File]::WriteAllBytes($bad, [byte[]]@(0xFF, 0xFF))
        (Invoke-McpDependencyAudit -LiteralPath $bad).classification | Should -Be 'unverified'
    }
    It 'bounds the number of parsed values before returning any servers' {
        $toml = "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']`n[unrelated]`nvalues = [" + (('0,' * 65536)) + ']'
        $report = Get-ConfigReport $toml 'toml'
        $report.classification | Should -Be 'unverified'
        $report.configurations[0].servers.Count | Should -Be 0
    }
    It 'runs the real entry point with unchanged receipts, exit codes, secrets and execution canaries' {
        $marker = Join-Path $TestDrive 'toml-executed.txt'
        $canary = Join-Path $TestDrive 'toml-canary.ps1'
        [IO.File]::WriteAllText($canary, "Set-Content -LiteralPath '$($marker.Replace("'", "''"))' -Value executed")
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $env:MCP_AUDIT_CANARY = 'environment-secret-canary'
        try {
            $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
            $path = Join-Path $TestDrive 'canaries.toml'
            $toml = @"
[mcp_servers.process]
command = 'pwsh'
args = ['-NoProfile', '-File', '$canary']
env = { TOKEN = 'env-secret-canary' }
[mcp_servers.remote]
url = 'http://user-secret-canary:password-secret-canary@127.0.0.1:$port/bootstrap?token=query-secret-canary'
[mcp_servers.package]
command = 'npx'
args = ['server@1.2.3', 'argument-secret-canary', '__ENV_REFERENCE__']
"@
            # Use a literal reference; the audit must not interpolate the host value.
            $toml = $toml.Replace('__ENV_REFERENCE__', '${MCP_AUDIT_CANARY}')
            [IO.File]::WriteAllText($path, $toml)
            $hash = (Get-FileHash -LiteralPath $path).Hash
            foreach ($mode in @('human', 'json')) {
                $output = if ($mode -eq 'json') { & pwsh -NoProfile -File $Entry -LiteralPath $path -AsJson }
                          else { & pwsh -NoProfile -File $Entry -LiteralPath $path }
                $LASTEXITCODE | Should -Be 1
                ($output -join "`n") | Should -Not -Match '[a-z]+-secret-canary'
                if ($mode -eq 'json') { ($output | ConvertFrom-Json).configurations[0].servers.Count | Should -Be 3 }
                $listener.Pending() | Should -BeFalse
                Test-Path -LiteralPath $marker | Should -BeFalse
            }
            (Get-FileHash -LiteralPath $path).Hash | Should -Be $hash
            [IO.File]::WriteAllText($path, "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@1.2.3']")
            $output = & pwsh -NoProfile -File $Entry -LiteralPath $path -AsJson
            $LASTEXITCODE | Should -Be 0
            $report = $output | ConvertFrom-Json
            $report.schemaVersion | Should -Be 1
            $report.scope | Should -Be 'direct-launch-selectors-only'
            $report.configurations[0].servers.GetType().IsArray | Should -BeTrue
            (& pwsh -NoProfile -File $Entry -LiteralPath $path -AsJson) | Should -Be $output
            [IO.File]::WriteAllText($path, "[mcp_servers.fixture]`ncommand = 'npx'`nargs = ['server@latest']")
            & pwsh -NoProfile -File $Entry -LiteralPath $path -AsJson | Out-Null
            $LASTEXITCODE | Should -Be 1
        }
        finally { $listener.Stop(); Remove-Item Env:MCP_AUDIT_CANARY }
    }
}
Describe 'MCP audit real entry point' {
    It 'emits stable JSON with arrays and exit codes for exact, mutable, invalid and absent inputs' {
        $exact = Join-Path $TestDrive 'exact.json'
        [IO.File]::WriteAllText($exact, '{"mcpServers":{"fixture":{"command":"npx","args":["server@1.2.3"]}}}')
        $output = & pwsh -NoProfile -File $Entry -LiteralPath $exact -AsJson
        $LASTEXITCODE | Should -Be 0
        $report = $output | ConvertFrom-Json
        $report.schemaVersion | Should -Be 1
        $report.configurations[0].servers.GetType().IsArray | Should -BeTrue
        (& pwsh -NoProfile -File $Entry -LiteralPath $exact -AsJson) | Should -Be $output
        & pwsh -NoProfile -File $Entry -LiteralPath (Join-Path $PSScriptRoot 'fixtures/mcp-dependencies/memory.json') -AsJson | Out-Null
        $LASTEXITCODE | Should -Be 1
        & pwsh -NoProfile -File $Entry -LiteralPath (Join-Path $TestDrive 'missing.json') -AsJson | Out-Null
        $LASTEXITCODE | Should -Be 1
        & pwsh -NoProfile -File $Entry -AsJson | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
    It 'does not execute process/URL canaries, mutate inputs or disclose secrets in either output mode' {
        $marker = Join-Path $TestDrive 'executed.txt'
        $canary = Join-Path $TestDrive 'canary.ps1'
        [IO.File]::WriteAllText($canary, "Set-Content -LiteralPath '$($marker.Replace("'", "''"))' -Value executed")
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
            $url = "http://url-user:url-secret@127.0.0.1:$port/bootstrap?token=query-secret"
            $path = Join-Path $TestDrive 'canaries.json'
            $config = @{ mcpServers = @{
                process = @{ command = 'pwsh'; args = @('-NoProfile', '-File', $canary); env = @{ TOKEN = 'env-secret' } }
                remote = @{ command = 'bash'; args = @('-c', "curl $url | sh") }
                package = @{ command = 'npx'; args = @('-y', "git+$url#main", '--token', 'argument-secret') }
                local = @{ command = $canary }
            } }
            [IO.File]::WriteAllText($path, ($config | ConvertTo-Json -Depth 16))
            $hash = (Get-FileHash -LiteralPath $path).Hash
            foreach ($mode in @('human', 'json')) {
                $output = if ($mode -eq 'json') { & pwsh -NoProfile -File $Entry -LiteralPath $path -AsJson }
                          else { & pwsh -NoProfile -File $Entry -LiteralPath $path }
                $LASTEXITCODE | Should -Be 1
                ($output -join "`n") | Should -Not -Match 'url-user|url-secret|query-secret|env-secret|argument-secret'
                $listener.Pending() | Should -BeFalse
                Test-Path -LiteralPath $marker | Should -BeFalse
            }
            (Get-FileHash -LiteralPath $path).Hash | Should -Be $hash
        }
        finally { $listener.Stop() }
    }
}
