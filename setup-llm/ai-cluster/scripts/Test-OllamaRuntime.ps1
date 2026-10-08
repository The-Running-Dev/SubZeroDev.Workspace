[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://127.0.0.1:11434',
    [string]$Model = 'gemma4:12b',
    [ValidateRange(512, 262144)]
    [int]$ContextTokens = 8192,
    [ValidateRange(1, 20)]
    [int]$Runs = 3,
    [ValidateRange(16, 4096)]
    [int]$MaxOutputTokens = 256,
    [int]$TimeoutSeconds = 600,
    [string]$OutputPath,
    [switch]$Force
)

# Phase 1 proof for a host-native Ollama runtime: reachable on loopback, bound to
# loopback, serving a local (never cloud) model, and how fast and where it runs.
# It never pulls a model and never stores prompt or response text.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isCi = ($env:CI -eq 'true') -or ($env:GITHUB_ACTIONS -eq 'true')
if (-not $Force -and $isCi -and $env:AI_CLUSTER_RUN_HARDWARE_SMOKE -ne '1') {
    Write-Host '[SKIP] Ollama runtime check requires a host Ollama install and is disabled in standard CI.' -ForegroundColor Yellow
    Write-Host '[SKIP] Set AI_CLUSTER_RUN_HARDWARE_SMOKE=1 (or pass -Force locally) to run it.' -ForegroundColor Yellow
    exit 0
}

. (Join-Path $PSScriptRoot 'OllamaProbe.ps1')

$BaseUrl = $BaseUrl.TrimEnd('/')
$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check {
    param([string]$Name, [ValidateSet('pass', 'warn', 'fail')][string]$Status, [string]$Detail)

    $checks.Add([ordered]@{ name = $Name; status = $Status; detail = $Detail })
    $label, $color = switch ($Status) {
        'pass' { '[OK]', 'Green' }
        'warn' { '[WARN]', 'Yellow' }
        'fail' { '[FAIL]', 'Red' }
    }
    Write-Host "$label $Name - $Detail" -ForegroundColor $color
}

$benchmarkPrompt = 'Write a PowerShell function named Get-Fibonacci that returns the first N Fibonacci numbers as an array. Reply with the code only.'
$promptSha256 = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($benchmarkPrompt))
).Replace('-', '').ToLowerInvariant()

$result = [ordered]@{
    schema_version = 1
    timestamp_utc  = (Get-Date).ToUniversalTime().ToString('o')
    runtime        = 'ollama'
    base_url       = $BaseUrl
    host           = Get-HostHardwareSummary
    ollama_version = $null
    binding        = $null
    model          = [ordered]@{ name = $Model; digest = $null; details = $null; was_loaded_before_run = $null }
    request        = [ordered]@{
        prompt_id         = 'powershell-fibonacci-v1'
        prompt_sha256     = $promptSha256
        num_ctx           = $ContextTokens
        num_predict       = $MaxOutputTokens
        temperature       = 0
        seed              = 42
    }
    runs           = @()
    summary        = $null
    placement      = $null
    checks         = $checks
}

try {
    if (-not (Test-LoopbackUrl -Url $BaseUrl)) {
        Add-Check 'loopback-url' 'fail' "$BaseUrl is not a loopback address; this check only talks to a local runtime."
        throw 'stop'
    }
    Add-Check 'loopback-url' 'pass' $BaseUrl

    try {
        $version = Invoke-RestMethod -Uri "$BaseUrl/api/version" -TimeoutSec 10
        $result.ollama_version = Get-OllamaField $version 'version'
        Add-Check 'reachable' 'pass' "Ollama $($result.ollama_version)"
    }
    catch {
        Add-Check 'reachable' 'fail' "No Ollama at $BaseUrl ($($_.Exception.Message)). Install it (winget install Ollama.Ollama) and start it."
        throw 'stop'
    }

    $port = ([Uri]$BaseUrl).Port
    $addresses = @(Get-TcpListenAddresses -Port $port)
    $loopbackOnly = Test-LoopbackOnlyBinding -Addresses $addresses
    $result.binding = [ordered]@{ port = $port; listen_addresses = $addresses; loopback_only = $loopbackOnly }
    if ($null -eq $loopbackOnly) {
        Add-Check 'loopback-binding' 'warn' "Could not determine which addresses port $port listens on."
    }
    elseif ($loopbackOnly) {
        Add-Check 'loopback-binding' 'pass' ($addresses -join ', ')
    }
    else {
        Add-Check 'loopback-binding' 'fail' "Port $port listens on $($addresses -join ', '). Ollama has no authentication; unset OLLAMA_HOST or set it to 127.0.0.1."
    }

    $tags = Invoke-RestMethod -Uri "$BaseUrl/api/tags" -TimeoutSec 10
    $localModels = @(Get-OllamaField $tags 'models')
    $cloudModels = @($localModels | Where-Object { Test-OllamaCloudModel -Entry $_ } | ForEach-Object { Get-OllamaField $_ 'name' })
    if ($cloudModels.Count -gt 0) {
        Add-Check 'cloud-models-present' 'warn' "Cloud models are registered ($($cloudModels -join ', ')). They run off this machine; keep them out of gateway routes."
    }

    $entry = Find-OllamaModel -Models $localModels -Name $Model
    if ($null -eq $entry) {
        Add-Check 'model-present' 'fail' "$Model is not pulled. This check never downloads; run: ollama pull $Model"
        throw 'stop'
    }
    if (Test-OllamaCloudModel -Entry $entry) {
        Add-Check 'model-local' 'fail' "$Model is a cloud model; it would send prompts to $(Get-OllamaField $entry 'remote_host')."
        throw 'stop'
    }
    $result.model.digest = Get-OllamaField $entry 'digest'
    $result.model.details = Get-OllamaField $entry 'details'
    Add-Check 'model-local' 'pass' "$Model digest $($result.model.digest)"

    $psBefore = Invoke-RestMethod -Uri "$BaseUrl/api/ps" -TimeoutSec 10
    $result.model.was_loaded_before_run = $null -ne (Find-OllamaModel -Models @(Get-OllamaField $psBefore 'models') -Name $Model)

    $runResults = for ($index = 1; $index -le $Runs; $index++) {
        $body = @{
            model      = $Model
            messages   = @(@{ role = 'user'; content = $benchmarkPrompt })
            keep_alive = '5m'
            options    = @{ num_ctx = $ContextTokens; num_predict = $MaxOutputTokens; temperature = 0; seed = 42 }
        }
        $chat = Invoke-OllamaStreamedChat -BaseUrl $BaseUrl -Body $body -TimeoutSeconds $TimeoutSeconds
        $metrics = ConvertTo-OllamaRunMetrics -Final $chat.Final -TtftMs $chat.TtftMs -WallMs $chat.WallMs
        $metrics['run'] = $index
        $metrics['response_chars'] = $chat.ContentChars
        Write-Host ("[INFO] run {0}: ttft {1} ms, generation {2} tok/s, prompt {3} tok/s, load {4} ms" -f
            $index, $metrics.ttft_ms, $metrics.generation_tokens_per_sec, $metrics.prompt_tokens_per_sec, $metrics.load_ms)
        $metrics
    }
    $result.runs = @($runResults)

    # Run 1 carries the load cost when the model was cold; the median uses warm runs when there are any.
    $warm = @(if ($Runs -gt 1) { $result.runs | Select-Object -Skip 1 } else { $result.runs })
    $result.summary = [ordered]@{
        first_run_load_ms                = $result.runs[0].load_ms
        first_run_ttft_ms                = $result.runs[0].ttft_ms
        median_ttft_ms                   = Get-MedianValue @($warm | ForEach-Object { $_.ttft_ms })
        median_prompt_tokens_per_sec     = Get-MedianValue @($warm | ForEach-Object { $_.prompt_tokens_per_sec })
        median_generation_tokens_per_sec = Get-MedianValue @($warm | ForEach-Object { $_.generation_tokens_per_sec })
        warm_runs                        = $warm.Count
    }
    Add-Check 'inference' 'pass' "$Runs run(s); median generation $($result.summary.median_generation_tokens_per_sec) tok/s"

    $psAfter = Invoke-RestMethod -Uri "$BaseUrl/api/ps" -TimeoutSec 10
    $loaded = Find-OllamaModel -Models @(Get-OllamaField $psAfter 'models') -Name $Model
    if ($null -eq $loaded) {
        Add-Check 'placement' 'warn' "$Model is not listed by /api/ps after the runs; placement unknown."
    }
    else {
        $result.placement = Get-OllamaPlacement -PsEntry $loaded
        $detail = "$($result.placement.gpu_percent)% of $($result.placement.size_mb) MB in GPU memory, context $($result.placement.context_length)"
        switch ($result.placement.placement) {
            'gpu' { Add-Check 'placement' 'pass' "fully on GPU: $detail" }
            'split' { Add-Check 'placement' 'warn' "split GPU/CPU: $detail" }
            default { Add-Check 'placement' 'warn' "not on GPU, GPU acceleration not verified: $detail" }
        }
    }
}
catch {
    if ($_.Exception.Message -ne 'stop') {
        Add-Check 'unexpected-error' 'fail' $_.Exception.Message
    }
}

if (-not $OutputPath) {
    $safeModel = $Model -replace '[^A-Za-z0-9._-]', '_'
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $OutputPath = Join-Path $PSScriptRoot "../state/ollama-runtime-$safeModel-$stamp.bench.json"
}
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "[INFO] Result written to $OutputPath"

$failed = @($checks | Where-Object { $_.status -eq 'fail' })
if ($failed.Count -gt 0) {
    Write-Host "[FAIL] Ollama runtime check failed: $(@($failed | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host '[OK] Ollama runtime check passed.' -ForegroundColor Green
exit 0
