BeforeAll {
    . (Join-Path $PSScriptRoot '../scripts/OllamaProbe.ps1')
    $script:runtimeScript = Join-Path $PSScriptRoot '../scripts/Test-OllamaRuntime.ps1'
    $script:mockScript = Join-Path $PSScriptRoot 'fixtures/mock-ollama.py'
    $script:python = if ($IsWindows) { 'python' } else { 'python3' }

    function Start-MockOllama {
        param([string[]]$ExtraArgs = @())

        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()

        $startArgs = @{ FilePath = $script:python; ArgumentList = (@($script:mockScript, '--port', $port) + $ExtraArgs); PassThru = $true }
        # -WindowStyle is Windows-only; pwsh on Linux rejects it.
        if ($IsWindows) { $startArgs.WindowStyle = 'Hidden' }
        $process = Start-Process @startArgs
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Date) -lt $deadline) {
            try {
                $null = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/version" -TimeoutSec 2
                return [pscustomobject]@{ Process = $process; BaseUrl = "http://127.0.0.1:$port" }
            }
            catch { Start-Sleep -Milliseconds 200 }
        }
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'Mock Ollama did not start.'
    }

    function Invoke-RuntimeCheck {
        param([string]$BaseUrl, [string]$Model = 'gemma4:12b', [int]$Runs = 2)

        $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) "ollama-runtime-test-$([guid]::NewGuid().ToString('N')).json"
        $output = & pwsh -NoProfile -File $script:runtimeScript -Force -BaseUrl $BaseUrl -Model $Model -Runs $Runs -OutputPath $outputPath 2>&1
        $exitCode = $LASTEXITCODE
        $json = if (Test-Path -LiteralPath $outputPath) { Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json } else { $null }
        Remove-Item -LiteralPath $outputPath -ErrorAction SilentlyContinue
        return [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join "`n"); Result = $json }
    }
}

Describe 'Ollama probe parsing' {
    It 'accepts only loopback base URLs' -ForEach @(
        @{ Url = 'http://127.0.0.1:11434'; Expected = $true }
        @{ Url = 'http://localhost:11434'; Expected = $true }
        @{ Url = 'http://[::1]:11434'; Expected = $true }
        @{ Url = 'http://0.0.0.0:11434'; Expected = $false }
        @{ Url = 'http://192.168.1.20:11434'; Expected = $false }
        @{ Url = 'https://ollama.com'; Expected = $false }
        @{ Url = 'not a url'; Expected = $false }
    ) {
        Test-LoopbackUrl -Url $Url | Should -Be $Expected
    }

    It 'flags cloud models by remote_host or tag suffix' -ForEach @(
        @{ Entry = @{ name = 'gemma4:12b' }; Expected = $false }
        @{ Entry = @{ name = 'gemma4:e4b-it-qat' }; Expected = $false }
        @{ Entry = @{ name = 'gemma4:cloud' }; Expected = $true }
        @{ Entry = @{ name = 'gemma4:31b-cloud' }; Expected = $true }
        @{ Entry = @{ name = 'renamed'; remote_host = 'https://ollama.com:443' }; Expected = $true }
    ) {
        Test-OllamaCloudModel -Entry ([pscustomobject]$Entry) | Should -Be $Expected
    }

    It 'resolves an untagged name to :latest' {
        $models = @([pscustomobject]@{ name = 'gemma4:latest' }, [pscustomobject]@{ name = 'gemma4:12b' })
        (Find-OllamaModel -Models $models -Name 'gemma4').name | Should -Be 'gemma4:latest'
        Find-OllamaModel -Models $models -Name 'gemma4:31b' | Should -BeNullOrEmpty
    }

    It 'converts nanosecond durations into rates and milliseconds' {
        $final = [pscustomobject]@{
            done = $true; done_reason = 'stop'
            total_duration = 2000000000; load_duration = 500000000
            prompt_eval_count = 40; prompt_eval_duration = 200000000
            eval_count = 100; eval_duration = 1000000000
        }
        $metrics = ConvertTo-OllamaRunMetrics -Final $final -TtftMs 612.34 -WallMs 2050

        $metrics.load_ms | Should -Be 500
        $metrics.total_ms | Should -Be 2000
        $metrics.prompt_tokens_per_sec | Should -Be 200
        $metrics.generation_tokens_per_sec | Should -Be 100
        $metrics.ttft_ms | Should -Be 612.3
    }

    It 'reports no rate rather than inventing one when a duration is missing' {
        $metrics = ConvertTo-OllamaRunMetrics -Final ([pscustomobject]@{ eval_count = 10; eval_duration = 0 })
        $metrics.generation_tokens_per_sec | Should -BeNullOrEmpty
        $metrics.prompt_tokens_per_sec | Should -BeNullOrEmpty
        $metrics.ttft_ms | Should -BeNullOrEmpty
    }

    It 'classifies placement from size and size_vram' -ForEach @(
        @{ Vram = 8000000000; Expected = 'gpu'; Percent = 100 }
        @{ Vram = 4000000000; Expected = 'split'; Percent = 50 }
        @{ Vram = 0; Expected = 'cpu'; Percent = 0 }
    ) {
        $placement = Get-OllamaPlacement -PsEntry ([pscustomobject]@{ size = 8000000000; size_vram = $Vram; context_length = 8192 })
        $placement.placement | Should -Be $Expected
        $placement.gpu_percent | Should -Be $Percent
    }

    It 'takes the median of the values present' {
        Get-MedianValue @(3, 1, 2) | Should -Be 2
        Get-MedianValue @(4, 1, 3, 2) | Should -Be 2.5
        Get-MedianValue @($null, 5) | Should -Be 5
        Get-MedianValue @() | Should -BeNullOrEmpty
    }

    It 'treats any non-loopback listen address as exposed' {
        Test-LoopbackOnlyBinding -Addresses @('127.0.0.1', '::1') | Should -BeTrue
        Test-LoopbackOnlyBinding -Addresses @('127.0.0.1', '0.0.0.0') | Should -BeFalse
        Test-LoopbackOnlyBinding -Addresses @('::') | Should -BeFalse
        Test-LoopbackOnlyBinding -Addresses @() | Should -BeNullOrEmpty
    }
}

Describe 'Test-OllamaRuntime.ps1' {
    It 'skips in standard CI unless explicitly enabled' {
        $text = Get-Content -LiteralPath $script:runtimeScript -Raw
        $text | Should -Match 'AI_CLUSTER_RUN_HARDWARE_SMOKE'
        $text | Should -Match '\[SKIP\]'
        $text | Should -Match 'disabled in standard CI'
    }

    It 'never pulls a model' {
        $text = Get-Content -LiteralPath $script:runtimeScript -Raw
        $text | Should -Not -Match '/api/pull'
    }

    It 'refuses a non-loopback runtime without contacting it' {
        $run = Invoke-RuntimeCheck -BaseUrl 'http://192.0.2.10:11434'
        $run.ExitCode | Should -Be 1
        ($run.Result.checks | Where-Object name -eq 'loopback-url').status | Should -Be 'fail'
    }

    Context 'against a mock runtime fully on GPU' {
        BeforeAll { $script:mock = Start-MockOllama }
        AfterAll { if ($script:mock) { Stop-Process -Id $script:mock.Process.Id -Force -ErrorAction SilentlyContinue } }

        It 'passes and records measured metrics without prompt or response text' {
            $run = Invoke-RuntimeCheck -BaseUrl $script:mock.BaseUrl
            $run.ExitCode | Should -Be 0 -Because $run.Output
            $run.Result.ollama_version | Should -Be '0.0.0-mock'
            $run.Result.model.digest | Should -Be ('0' * 64)
            @($run.Result.runs).Count | Should -Be 2
            $run.Result.runs[0].generation_tokens_per_sec | Should -Be 100
            $run.Result.runs[0].ttft_ms | Should -BeGreaterThan 0
            $run.Result.summary.warm_runs | Should -Be 1
            $run.Result.placement.placement | Should -Be 'gpu'
            $run.Result.request.prompt_sha256 | Should -Match '^[0-9a-f]{64}$'
            ($run.Result | ConvertTo-Json -Depth 10) | Should -Not -Match 'Get-Fibonacci|Reply with the code|mock reply'
        }

        It 'fails when the model is not pulled and says how to pull it' {
            $run = Invoke-RuntimeCheck -BaseUrl $script:mock.BaseUrl -Model 'gemma4:e4b' -Runs 1
            $run.ExitCode | Should -Be 1
            $check = $run.Result.checks | Where-Object name -eq 'model-present'
            $check.status | Should -Be 'fail'
            $check.detail | Should -Match 'ollama pull gemma4:e4b'
        }
    }

    Context 'against a mock runtime with cloud models and CPU offload' {
        BeforeAll { $script:mock = Start-MockOllama -ExtraArgs @('--vram-fraction', '0.5', '--include-cloud') }
        AfterAll { if ($script:mock) { Stop-Process -Id $script:mock.Process.Id -Force -ErrorAction SilentlyContinue } }

        It 'refuses to benchmark a cloud model' {
            $run = Invoke-RuntimeCheck -BaseUrl $script:mock.BaseUrl -Model 'gemma4:31b-cloud' -Runs 1
            $run.ExitCode | Should -Be 1
            ($run.Result.checks | Where-Object name -eq 'model-local').status | Should -Be 'fail'
            @($run.Result.runs).Count | Should -Be 0
        }

        It 'reports a GPU/CPU split as a warning, not as GPU acceleration' {
            $run = Invoke-RuntimeCheck -BaseUrl $script:mock.BaseUrl -Runs 1
            $run.ExitCode | Should -Be 0 -Because $run.Output
            $run.Result.placement.placement | Should -Be 'split'
            ($run.Result.checks | Where-Object name -eq 'placement').status | Should -Be 'warn'
            ($run.Result.checks | Where-Object name -eq 'cloud-models-present').status | Should -Be 'warn'
        }
    }
}
