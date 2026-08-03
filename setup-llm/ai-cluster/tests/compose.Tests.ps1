Describe 'AI cluster compose skeleton' {
    It 'has a compose file' {
        $composePath = Join-Path $PSScriptRoot '../compose.yaml'
        Test-Path -LiteralPath $composePath -PathType Leaf | Should -BeTrue
    }

    It 'renders headless config when docker is available' {
        if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'Docker is not installed in this environment.'
            return
        }

        $composePath = Join-Path $PSScriptRoot '../compose.yaml'
        $composeDirectory = Split-Path -Parent $composePath
        Push-Location $composeDirectory
        try {
            docker compose --file $composePath --profile headless config *> $null
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Pop-Location
        }
    }
}
