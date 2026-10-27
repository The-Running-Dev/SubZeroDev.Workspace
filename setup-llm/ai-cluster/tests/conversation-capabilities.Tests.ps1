BeforeDiscovery {
    $modulePath = Join-Path $PSScriptRoot '../../scripts/modules/ConversationCapabilities.psm1'
    Import-Module $modulePath -Force
}

Describe 'Read-only conversation capabilities' {
    InModuleScope ConversationCapabilities {
        BeforeAll {
            function Write-EvidenceFixture {
                param($Path, $Tools, $Graph = $null, $ObservedAt = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
                $value = @{ schemaVersion = 1; observedAt = $ObservedAt; host = @{ name = 'codex'; version = '26.1021.3705.0'; tools = @($Tools) } }
                if ($null -ne $Graph) { $value.contextGraph = $Graph }
                $value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path
            }
            function Find-Capability($Report, $Id) { $Report.capabilities | Where-Object id -EQ $Id }
        }
        BeforeEach {
            Mock Invoke-CapabilityProbe { @{ state = 'unavailable'; code = 'command-absent'; output = '' } }
            $config = Join-Path $TestDrive 'absent-config.json'
            $extensions = Join-Path $TestDrive 'absent-extensions'
        }

        It 'retains portable fork/attach/return when optional tools are absent' {
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions
            $report.readOnly | Should -BeTrue
            @($report.capabilities).Count | Should -Be 13
            (Find-Capability $report 'graphify.cli').status | Should -Be unavailable
            (Find-Capability $report 'memorykit.configuration').status | Should -Be unconfigured
            (Find-Capability $report 'context-graph.live').status | Should -Be unknown
            $report.adapters[0].status | Should -Be supported
            $report.agentKitHost.tools.Count | Should -Be 0
        }

        It 'redacts failed probes and does not turn a failure into absence' {
            Mock Invoke-CapabilityProbe { @{ state = 'unknown'; code = 'probe-failed'; output = 'SECRET-PROBE-OUTPUT' } }
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions
            (Find-Capability $report 'graphify.cli').status | Should -Be unknown
            (Find-Capability $report 'memory-mcp.codex').status | Should -Be unknown
            ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-PROBE-OUTPUT'
        }

        It 'recognizes supplied Graphify contracts without indexing input' {
            Mock Invoke-CapabilityProbe { @{ state = 'supported'; code = 'probe-succeeded'; output = 'graphify 0.9.91' } } -ParameterFilter { $Command -eq 'graphify' }
            $package = New-Item -ItemType Directory (Join-Path $TestDrive 'graphify') -Force
            Set-Content (Join-Path $package 'detect.py') "DOC_EXTENSIONS = {'.md', '.txt'} # extra_excludes .gitignore"
            Set-Content (Join-Path $package 'validate.py') 'REQUIRED_EDGE_FIELDS = {"source", "target", "relation", "confidence", "source_file"}'
            $before = @(Get-ChildItem $package | Get-FileHash | ForEach-Object Hash)
            $report = Get-ConversationCapabilityReport -GraphifyPackagePath $package -MemoryConfigPath $config -ExtensionsPath $extensions
            foreach ($id in @('graphify.inputs', 'graphify.relationships', 'graphify.exclusions')) {
                $entry = Find-Capability $report $id
                $entry.status | Should -Be supported
                $entry.evidence.code | Should -Be supplied-source-declaration
                $entry.evidence.details.sourceSha256 | Should -Match '^[a-f0-9]{64}$'
            }
            @(Get-ChildItem $package | Get-FileHash | ForEach-Object Hash) | Should -Be $before
            Should -Invoke Invoke-CapabilityProbe -Times 1 -Exactly -ParameterFilter { $Command -eq 'graphify' -and ($Arguments -join ' ') -eq '--version' }
        }

        It 'does not infer relationships from an unrecognized Graphify version or source' {
            Mock Invoke-CapabilityProbe { @{ state = 'supported'; code = 'probe-succeeded'; output = 'unexpected PRIVATE text' } } -ParameterFilter { $Command -eq 'graphify' }
            $report = Get-ConversationCapabilityReport -GraphifyPackagePath $TestDrive -MemoryConfigPath $config -ExtensionsPath $extensions
            (Find-Capability $report 'graphify.relationships').status | Should -Be unknown
            ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'PRIVATE text'
        }

        It 'separates registered memory MCP from MemoryKit access for empty and single-server arrays' {
            Mock Invoke-CapabilityProbe { @{ state = 'supported'; code = 'probe-succeeded'; output = '[]' } } -ParameterFilter { $Command -eq 'codex' }
            (Get-MemoryCapabilities $config '' | Where-Object id -EQ 'memory-mcp.codex').status | Should -Be unconfigured
            Mock Invoke-CapabilityProbe { @{ state = 'supported'; code = 'probe-succeeded'; output = '[{"name":"memory","enabled":true,"env":{"TOKEN":"SECRET-MCP"}}]' } } -ParameterFilter { $Command -eq 'codex' }
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions
            $mcp = Find-Capability $report 'memory-mcp.codex'
            $mcp.evidence.details.registered | Should -BeTrue
            $mcp.status | Should -Be unknown
            (Find-Capability $report 'memorykit.configuration').status | Should -Be unconfigured
            ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-MCP|TOKEN'
        }

        It 'does not execute configured CLIs, open stores, or disclose namespace/configuration values' {
            $cli = Join-Path $TestDrive 'do-not-run.ps1'
            Set-Content $cli "throw 'This CLI must never run'"
            $store = New-Item -ItemType Directory (Join-Path $TestDrive 'private-store') -Force
            Set-Content (Join-Path $store 'memory.db') 'synthetic store bytes'
            $config = Join-Path $TestDrive 'configured.json'
            @{ cli = $cli; store = $store.FullName; capture = $true; context = $false; token = 'SECRET-CONFIG' } | ConvertTo-Json | Set-Content $config
            $before = (Get-FileHash (Join-Path $store 'memory.db')).Hash
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -Namespace 'PRIVATE-NAMESPACE' -ExtensionsPath $extensions
            $entry = Find-Capability $report 'memorykit.configuration'
            $entry.status | Should -Be unknown
            $entry.evidence.details.cliAvailable | Should -BeTrue
            $entry.evidence.details.storePresent | Should -BeTrue
            $entry.evidence.details.captureEnabled | Should -BeTrue
            (Find-Capability $report 'memorykit.namespace').evidence.details.storeOpened | Should -BeFalse
            ($report | ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-CONFIG|PRIVATE-NAMESPACE|private-store|do-not-run'
            (Get-FileHash (Join-Path $store 'memory.db')).Hash | Should -Be $before
            @(Get-ChildItem $store).Count | Should -Be 1
            Should -Invoke Invoke-CapabilityProbe -Times 0 -Exactly -ParameterFilter { $Command -eq $cli }
        }

        It 'reports malformed memory configuration conservatively' {
            $config = Join-Path $TestDrive 'bad-config.json'
            Set-Content $config '{"secret":"SECRET-INVALID"}'
            $entries = @(Get-MemoryCapabilities $config '')
            $entries[0].status | Should -Be unknown
            ($entries | ConvertTo-Json -Depth 10) | Should -Not -Match SECRET-INVALID
        }

        It 'inventories actual extension command IDs after a malformed sibling manifest' {
            $extensions = New-Item -ItemType Directory (Join-Path $TestDrive 'extension-fixture') -Force
            $bad = New-Item -ItemType Directory (Join-Path $extensions 'a-bad') -Force
            Set-Content (Join-Path $bad 'package.json') '{bad json'
            $good = New-Item -ItemType Directory (Join-Path $extensions 'z-good') -Force
            @{ publisher = 'fixture'; name = 'memory-tools'; version = '1.2.3'; contributes = @{ commands = @(@{ command = 'fixture.memory.read'; title = 'Read memory' }, @{ command = 'fixture.other'; title = 'Other' }, @{ command = 'SECRET invalid command'; title = 'Memory' }) }; secret = 'SECRET-MANIFEST' } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $good 'package.json')
            $entry = Get-EditorCapabilities $extensions
            $entry.status | Should -Be unknown
            $entry.evidence.code | Should -Be manifest-declarations-only
            $entry.evidence.details.extensions.Count | Should -Be 1
            $entry.evidence.details.extensions[0].id | Should -Be fixture.memory-tools
            $entry.evidence.details.extensions[0].commands | Should -Be @('fixture.memory.read')
            ($entry | ConvertTo-Json -Depth 10) | Should -Not -Match 'SECRET|fixture.other'
        }

        It 'maps a partial host into the existing AgentKit capabilities contract' {
            $evidence = Join-Path $TestDrive 'partial.json'
            Write-EvidenceFixture $evidence @(@{ name = 'create_thread'; status = 'supported'; verification = 'contract' }, @{ name = 'fork_thread'; status = 'unavailable'; verification = 'contract' })
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions -EvidencePath $evidence
            $report.agentKitHost.host | Should -Be codex
            $report.agentKitHost.tools | Should -Be @('mcp__codex_app__create_thread')
            (Find-Capability $report 'host.create_thread').evidence.details.verification | Should -Be contract
            (Find-Capability $report 'host.read_thread').status | Should -Be unknown
            $report.adapters[1].status | Should -Be supported
            $report.adapters[2].status | Should -Be unavailable
            $report.adapters[3].status | Should -Be unknown
        }

        It 'accepts current full smoke evidence without treating it as action authorization' {
            $evidence = Join-Path $TestDrive 'supported.json'
            $tools = @('create_thread', 'fork_thread', 'navigate_to_codex_page', 'read_thread') | ForEach-Object { @{ name = $_; status = 'supported'; verification = 'smoke' } }
            Write-EvidenceFixture $evidence $tools
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions -EvidencePath $evidence
            $report.agentKitHost.tools.Count | Should -Be 4
            $report.agentKitHost.evidence | Should -Match 'no action authorized'
            $report.adapters[3].status | Should -Be supported
        }

        It 'rejects stale, duplicate and invented host evidence' -ForEach @(
            @{ Case = 'stale' }, @{ Case = 'duplicate' }, @{ Case = 'invented' }
        ) {
            $evidence = Join-Path $TestDrive "$Case.json"
            $tools = @(@{ name = 'fork_thread'; status = 'supported'; verification = 'contract' })
            if ($Case -eq 'duplicate') { $tools += $tools[0] }
            if ($Case -eq 'invented') { $tools[0].name = 'selectively_clone_history' }
            $date = if ($Case -eq 'stale') { [DateTimeOffset]::UtcNow.AddDays(-8).ToString('yyyy-MM-ddTHH:mm:ssZ') } else { [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') }
            Write-EvidenceFixture $evidence $tools -ObservedAt $date
            $report = Get-ConversationCapabilityReport -MemoryConfigPath $config -ExtensionsPath $extensions -EvidencePath $evidence
            $report.agentKitHost.tools.Count | Should -Be 0
            (Find-Capability $report 'host.fork_thread').evidence.code | Should -Be manual-evidence-invalid-or-stale
        }

        It 'requires a live owner and hashed contract instead of historical design state' {
            $evidence = Join-Path $TestDrive 'graph.json'
            $design = New-Item -ItemType Directory (Join-Path $TestDrive 'design') -Force
            $contract = Join-Path $design 'context-graph.md'
            Set-Content $contract 'historical state'
            Write-EvidenceFixture $evidence @() @{ status = 'supported'; live = $true; owner = 'fixture'; contractPath = $contract }
            (Get-ManualCapabilities $evidence | Where-Object id -EQ 'context-graph.live').status | Should -Be unknown
            $contract = Join-Path $TestDrive 'live-contract.md'
            Set-Content $contract 'synthetic owner contract'
            Write-EvidenceFixture $evidence @() @{ status = 'supported'; live = $true; owner = 'fixture'; contractPath = $contract }
            $entry = Get-ManualCapabilities $evidence | Where-Object id -EQ 'context-graph.live'
            $entry.status | Should -Be supported
            $entry.evidence.details.contractSha256 | Should -Match '^[a-f0-9]{64}$'
            ($entry | ConvertTo-Json -Depth 10) | Should -Not -Match 'live-contract.md|synthetic owner'
        }
    }
}

Describe 'Capability probe subprocess boundary' {
    InModuleScope ConversationCapabilities {
        It 'discards stdout/stderr from a failed real subprocess' {
            $shim = Join-Path $TestDrive 'failed.ps1'
            Set-Content $shim "'SECRET-STDOUT'; [Console]::Error.WriteLine('SECRET-STDERR'); exit 3"
            $result = Invoke-CapabilityProbe $shim @()
            $result.state | Should -Be unknown
            $result.code | Should -Be probe-failed
            $result.output | Should -Be ''
        }
        It 'terminates a timed-out subprocess' {
            $shim = Join-Path $TestDrive 'slow.ps1'
            Set-Content $shim 'Start-Sleep -Seconds 20'
            $result = Invoke-CapabilityProbe $shim @() -TimeoutMilliseconds 100
            $result.code | Should -Be probe-timeout
            $result.output | Should -Be ''
        }
    }
}
