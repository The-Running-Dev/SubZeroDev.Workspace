Describe 'LiteLLM route contract skeleton' {
    BeforeAll {
        $configText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../config/litellm.yaml') -Raw
        $composeText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../compose.yaml') -Raw
        $envExampleText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.env.example') -Raw
    }

    It 'defines coding, general, vision, multimodal, fast, and embeddings aliases' {
        foreach ($alias in @('coding', 'general', 'vision', 'multimodal', 'fast', 'embeddings')) {
            $configText | Should -Match "model_name:\s*$alias\b"
        }
    }

    It 'takes every backend model id from the environment' {
        $configText | Should -Match 'model:\s*os\.environ/LOCAL_CODING_MODEL'
        $configText | Should -Match 'model:\s*os\.environ/LOCAL_FAST_MODEL'
        $configText | Should -Match 'model:\s*os\.environ/LOCAL_EMBEDDINGS_MODEL'
        $configText | Should -Not -Match 'model:\s*openai/'
    }

    It 'defaults the backend model ids to the llama-server names' {
        $composeText | Should -Match 'LOCAL_CODING_MODEL:\s*\$\{LOCAL_CODING_MODEL:-openai/local-coding\}'
        $composeText | Should -Match 'LOCAL_FAST_MODEL:\s*\$\{LOCAL_FAST_MODEL:-openai/local-coding\}'
        $composeText | Should -Match 'LOCAL_EMBEDDINGS_MODEL:\s*\$\{LOCAL_EMBEDDINGS_MODEL:-openai/local-embeddings\}'
    }

    It 'never routes an alias to an Ollama cloud tag by default' {
        $active = ($envExampleText -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $active | Should -Not -Match '[-:]cloud\b'
        $configText | Should -Not -Match '-cloud\b|:cloud\b'
        $composeText | Should -Not -Match 'gemma4:[^\s}]*cloud'
    }
}
