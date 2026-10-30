#Requires -Version 7.0
BeforeAll {
    $script:Entry = Join-Path $PSScriptRoot '../../scripts/Manage-AISettings.ps1'
    $script:Pwsh = (Get-Process -Id $PID).Path
    $script:Node = (Get-Command node -ErrorAction Stop).Source
    function Invoke-FixtureCommand {
        param([string[]]$Options)
        $text = & $script:Pwsh -NoProfile -File $script:Entry @Options -SandboxRoot $script:FixtureRoot -NodePath $script:Node -AsJson
        $script:ResultCode = $LASTEXITCODE
        return ($text -join "`n" | ConvertFrom-Json -AsHashtable)
    }
}

Describe 'AI settings temporary-profile entry point' {
    BeforeEach {
        $script:FixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-settings-pester-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:FixtureRoot 'claude') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FixtureRoot 'codex') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $script:FixtureRoot 'claude/settings.json'), '{"model":"opus"}')
        [IO.File]::WriteAllText((Join-Path $script:FixtureRoot 'codex/config.toml'), 'model="fixture-model"')
    }
    AfterEach {
        # Only the exact GUID temporary directory created by this test is removed.
        $resolved = [IO.Path]::GetFullPath($script:FixtureRoot)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolved.StartsWith($tempRoot) -or (Split-Path $resolved -Leaf) -notmatch '^ai-settings-pester-[a-f0-9]{32}$') {
            throw 'Refusing cleanup outside the fixture directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }

    It 'captures twice, returns JSON, and keeps exit zero on change' {
        $first = Invoke-FixtureCommand @('capture')
        $script:ResultCode | Should -Be 0
        $first.changed | Should -BeTrue
        $second = Invoke-FixtureCommand @('capture')
        $script:ResultCode | Should -Be 0
        $second.changed | Should -BeFalse
    }

    It 'previews without writes, then restores only fixture files' {
        $null = Invoke-FixtureCommand @('capture')
        $target = Join-Path $script:FixtureRoot 'codex/config.toml'
        [IO.File]::WriteAllText($target, 'model="changed"')
        $before = [IO.File]::ReadAllText($target)
        $preview = Invoke-FixtureCommand @('restore', '-WhatIf', '-Force')
        $script:ResultCode | Should -Be 0
        $preview.wouldChange | Should -BeTrue
        $preview.changed | Should -BeFalse
        [IO.File]::ReadAllText($target) | Should -BeExactly $before
        Test-Path (Join-Path $script:FixtureRoot 'private-backups') | Should -BeFalse
        $restored = Invoke-FixtureCommand @('restore', '-Force')
        $script:ResultCode | Should -Be 0
        $restored.changed | Should -BeTrue
        [IO.File]::ReadAllText($target) | Should -Match 'fixture-model'
    }

    It 'honors explicit sandbox overrides and attention exit policy' {
        $data = Join-Path $script:FixtureRoot 'alternate/data.json'
        $result = Invoke-FixtureCommand @('capture', '-DataPath', $data)
        $script:ResultCode | Should -Be 0
        $result.changed | Should -BeTrue
        Test-Path -LiteralPath $data | Should -BeTrue
        [IO.File]::WriteAllText((Join-Path $script:FixtureRoot 'claude/settings.json'), '{"unknown":42}')
        $status = Invoke-FixtureCommand @('status', '-DataPath', $data, '-FailOnAttention')
        $script:ResultCode | Should -Be 2
        $status.attention.Count | Should -Be 1
    }

    It 'reports a specific error for WhatIf outside restore' {
        foreach ($command in 'capture', 'status') {
            $result = Invoke-FixtureCommand @($command, '-WhatIf')
            $script:ResultCode | Should -Be 1
            $result.error | Should -BeExactly 'what-if-requires-restore'
            Test-Path (Join-Path $script:FixtureRoot 'repo') | Should -BeFalse
        }
    }

    It 'refuses an outside profile without opening it' {
        $outside = Join-Path ([IO.Path]::GetTempPath()) 'not-authorized-profile'
        $result = Invoke-FixtureCommand @('capture', '-CodexHome', $outside)
        $script:ResultCode | Should -Be 1
        $result.error | Should -BeExactly 'path-outside-sandbox-or-linked'
        Test-Path (Join-Path $script:FixtureRoot 'repo') | Should -BeFalse
    }
}
