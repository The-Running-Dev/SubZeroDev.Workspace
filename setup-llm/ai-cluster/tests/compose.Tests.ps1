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
        $envExample = Join-Path $composeDirectory '.env.example'
        $envFile = Join-Path $composeDirectory '.env'
        $hadEnvFile = Test-Path -LiteralPath $envFile -PathType Leaf
        $envBackup = Join-Path $composeDirectory '.env.compose-test.backup'

        if ($hadEnvFile) {
            Copy-Item -LiteralPath $envFile -Destination $envBackup -Force
        }
        else {
            Copy-Item -LiteralPath $envExample -Destination $envFile -Force
        }

        Push-Location $composeDirectory
        try {
            docker compose --file $composePath --profile headless config *> $null
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            Pop-Location
            if ($hadEnvFile) {
                if (Test-Path -LiteralPath $envBackup -PathType Leaf) {
                    Move-Item -LiteralPath $envBackup -Destination $envFile -Force
                }
            }
            else {
                if (Test-Path -LiteralPath $envFile -PathType Leaf) {
                    Remove-Item -LiteralPath $envFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
