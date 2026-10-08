# Dot-source library for Test-OllamaRuntime.ps1. Pure parsing and metric functions
# are kept free of I/O so tests can drive them with recorded Ollama responses.

Set-StrictMode -Version Latest

function Get-OllamaField {
    param($Object, [string]$Name)

    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-LoopbackUrl {
    param([Parameter(Mandatory)][string]$Url)

    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { return $false }
    $hostName = $uri.Host.Trim('[', ']')
    if ($hostName -eq 'localhost') { return $true }

    $address = $null
    if ([System.Net.IPAddress]::TryParse($hostName, [ref]$address)) {
        return [System.Net.IPAddress]::IsLoopback($address)
    }
    return $false
}

function Test-OllamaCloudModel {
    # A cloud model runs on ollama.com, not this machine: /api/tags marks it with
    # remote_host, and its tag ends in "cloud" (gemma4:cloud, gemma4:31b-cloud).
    param([Parameter(Mandatory)]$Entry)

    $remoteHost = [string](Get-OllamaField $Entry 'remote_host')
    if (-not [string]::IsNullOrWhiteSpace($remoteHost)) { return $true }

    $name = [string](Get-OllamaField $Entry 'name')
    if ([string]::IsNullOrWhiteSpace($name)) { $name = [string](Get-OllamaField $Entry 'model') }
    return $name -match '[:-]cloud$'
}

function Find-OllamaModel {
    param([Parameter(Mandatory)]$Models, [Parameter(Mandatory)][string]$Name)

    foreach ($entry in @($Models)) {
        if ((Get-OllamaField $entry 'name') -eq $Name -or (Get-OllamaField $entry 'model') -eq $Name) {
            return $entry
        }
    }
    # Ollama treats an untagged name as :latest.
    if ($Name -notmatch ':') { return Find-OllamaModel -Models $Models -Name "${Name}:latest" }
    return $null
}

function ConvertTo-OllamaRate {
    param($Count, $DurationNs)

    if ($null -eq $Count -or $null -eq $DurationNs -or [double]$DurationNs -le 0) { return $null }
    return [math]::Round([double]$Count / ([double]$DurationNs / 1e9), 2)
}

function ConvertTo-OllamaMilliseconds {
    param($DurationNs)

    if ($null -eq $DurationNs) { return $null }
    return [math]::Round([double]$DurationNs / 1e6, 1)
}

function ConvertTo-OllamaRunMetrics {
    # Final is the done=true chunk of a /api/chat response; its durations are nanoseconds.
    param(
        [Parameter(Mandatory)]$Final,
        $TtftMs,
        $WallMs
    )

    $promptCount = Get-OllamaField $Final 'prompt_eval_count'
    $promptNs = Get-OllamaField $Final 'prompt_eval_duration'
    $evalCount = Get-OllamaField $Final 'eval_count'
    $evalNs = Get-OllamaField $Final 'eval_duration'

    return [ordered]@{
        ttft_ms                   = if ($null -eq $TtftMs) { $null } else { [math]::Round([double]$TtftMs, 1) }
        wall_ms                   = if ($null -eq $WallMs) { $null } else { [math]::Round([double]$WallMs, 1) }
        load_ms                   = ConvertTo-OllamaMilliseconds (Get-OllamaField $Final 'load_duration')
        total_ms                  = ConvertTo-OllamaMilliseconds (Get-OllamaField $Final 'total_duration')
        prompt_tokens             = $promptCount
        prompt_tokens_per_sec     = ConvertTo-OllamaRate $promptCount $promptNs
        generation_tokens         = $evalCount
        generation_tokens_per_sec = ConvertTo-OllamaRate $evalCount $evalNs
        done_reason               = Get-OllamaField $Final 'done_reason'
    }
}

function Get-OllamaPlacement {
    # /api/ps reports the loaded footprint (size) and the part resident in GPU memory
    # (size_vram). Their ratio is the only GPU evidence this probe claims.
    param([Parameter(Mandatory)]$PsEntry)

    $size = [double](Get-OllamaField $PsEntry 'size')
    $sizeVram = [double](Get-OllamaField $PsEntry 'size_vram')
    $gpuPercent = if ($size -gt 0) { [math]::Round(100 * $sizeVram / $size, 1) } else { $null }

    $placement = if ($null -eq $gpuPercent) { 'unknown' }
        elseif ($gpuPercent -ge 100) { 'gpu' }
        elseif ($gpuPercent -le 0) { 'cpu' }
        else { 'split' }

    return [ordered]@{
        size_mb        = [math]::Round($size / 1MB, 0)
        size_vram_mb   = [math]::Round($sizeVram / 1MB, 0)
        gpu_percent    = $gpuPercent
        placement      = $placement
        context_length = Get-OllamaField $PsEntry 'context_length'
    }
}

function Get-MedianValue {
    param([object[]]$Values)

    $numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ } | Sort-Object)
    if ($numbers.Count -eq 0) { return $null }
    $middle = [int][math]::Floor($numbers.Count / 2)
    if ($numbers.Count % 2 -eq 1) { return $numbers[$middle] }
    return ($numbers[$middle - 1] + $numbers[$middle]) / 2
}

function Invoke-OllamaStreamedChat {
    # Streams /api/chat so time to first token is measured client-side, not inferred.
    # Returns the final chunk plus timings; the response text is counted, never kept.
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][hashtable]$Body,
        [int]$TimeoutSeconds = 600
    )

    $Body['stream'] = $true
    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, "$($BaseUrl.TrimEnd('/'))/api/chat")
        $request.Content = [System.Net.Http.StringContent]::new(($Body | ConvertTo-Json -Depth 10 -Compress), [System.Text.Encoding]::UTF8, 'application/json')

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            $errorText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            throw "Ollama /api/chat returned HTTP $([int]$response.StatusCode): $errorText"
        }

        $reader = [System.IO.StreamReader]::new($response.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
        $ttftMs = $null
        $contentChars = 0
        $final = $null
        while ($null -ne ($line = $reader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $chunk = $line | ConvertFrom-Json
            $errorField = Get-OllamaField $chunk 'error'
            if ($errorField) { throw "Ollama /api/chat stream error: $errorField" }

            $message = Get-OllamaField $chunk 'message'
            $piece = [string](Get-OllamaField $message 'content') + [string](Get-OllamaField $message 'thinking')
            if ($piece.Length -gt 0) {
                if ($null -eq $ttftMs) { $ttftMs = $stopwatch.Elapsed.TotalMilliseconds }
                $contentChars += $piece.Length
            }
            if (Get-OllamaField $chunk 'done') { $final = $chunk }
        }
        $stopwatch.Stop()

        if ($null -eq $final) { throw 'Ollama /api/chat stream ended without a done=true chunk.' }
        return [pscustomobject]@{
            Final        = $final
            TtftMs       = $ttftMs
            WallMs       = $stopwatch.Elapsed.TotalMilliseconds
            ContentChars = $contentChars
        }
    }
    finally {
        $client.Dispose()
    }
}

function Get-TcpListenAddresses {
    # Which local addresses the runtime is bound to. Empty when it cannot be determined.
    param([Parameter(Mandatory)][int]$Port)

    if ($IsWindows -and (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        return @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object { [string]$_.LocalAddress } | Sort-Object -Unique)
    }
    if ($IsLinux -and (Get-Command ss -ErrorAction SilentlyContinue)) {
        return @(& ss -ltnH "sport = :$Port" 2>$null | ForEach-Object {
            $local = ($_ -split '\s+')[3]
            if ($local) { $local.Substring(0, $local.LastIndexOf(':')).Trim('[', ']') }
        } | Sort-Object -Unique)
    }
    return @()
}

function Test-LoopbackOnlyBinding {
    param([string[]]$Addresses)

    if (-not $Addresses -or $Addresses.Count -eq 0) { return $null }
    foreach ($address in $Addresses) {
        $parsed = $null
        if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsed)) { return $false }
        if (-not [System.Net.IPAddress]::IsLoopback($parsed)) { return $false }
    }
    return $true
}

function Get-HostHardwareSummary {
    # Machine identity for a benchmark record. Reports only what the OS states.
    $summary = [ordered]@{
        os       = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        cpu      = $null
        ram_gb   = $null
        gpus     = @()
    }

    if ($IsWindows) {
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($computer) { $summary.ram_gb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1) }
        $processor = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($processor) { $summary.cpu = $processor.Name.Trim() }
        $summary.gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {
            [ordered]@{ name = $_.Name; driver_version = $_.DriverVersion }
        })
    }
    elseif ($IsLinux) {
        $memLine = Get-Content /proc/meminfo -ErrorAction SilentlyContinue | Where-Object { $_ -match '^MemTotal:\s+(\d+)' } | Select-Object -First 1
        if ($memLine -match '(\d+)') { $summary.ram_gb = [math]::Round([double]$Matches[1] / 1MB, 1) }
        $cpuLine = Get-Content /proc/cpuinfo -ErrorAction SilentlyContinue | Where-Object { $_ -match '^model name\s*:' } | Select-Object -First 1
        if ($cpuLine) { $summary.cpu = ($cpuLine -split ':', 2)[1].Trim() }
        if (Get-Command lspci -ErrorAction SilentlyContinue) {
            $summary.gpus = @(& lspci 2>$null | Where-Object { $_ -match 'VGA|3D controller|Display controller' } | ForEach-Object {
                [ordered]@{ name = ($_ -split ':\s', 2)[-1]; driver_version = $null }
            })
        }
    }
    elseif ($IsMacOS) {
        $bytes = & sysctl -n hw.memsize 2>$null
        if ($bytes) { $summary.ram_gb = [math]::Round([double]$bytes / 1GB, 1) }
        $summary.cpu = (& sysctl -n machdep.cpu.brand_string 2>$null)
    }

    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $nvidia = @(& nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits 2>$null)
        if ($LASTEXITCODE -eq 0 -and $nvidia.Count -gt 0) {
            $summary['nvidia'] = @($nvidia | ForEach-Object {
                $parts = $_ -split ',\s*'
                [ordered]@{ name = $parts[0]; driver_version = $parts[1]; memory_mb = [int]$parts[2] }
            })
        }
    }

    return $summary
}
