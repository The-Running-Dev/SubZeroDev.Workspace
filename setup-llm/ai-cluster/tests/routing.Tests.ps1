Describe 'LiteLLM route contract skeleton' {
    It 'defines coding, general, and embeddings aliases' {
        $configPath = Join-Path $PSScriptRoot '../config/litellm.yaml'
        $text = Get-Content -LiteralPath $configPath -Raw

        $text | Should -Match 'model_name:\s*coding'
        $text | Should -Match 'model_name:\s*general'
        $text | Should -Match 'model_name:\s*embeddings'
    }
}
