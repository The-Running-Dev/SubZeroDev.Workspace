[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('docs', 'setup', 'pwsh')]
    [string]$Mode = 'docs',

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArgument = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

switch ($Mode) {
    'docs' {
        $nginxConfig = '/etc/nginx/sites-enabled/default'
        $config = Get-Content -LiteralPath $nginxConfig -Raw
        $config = $config -replace 'listen 80 default_server;', 'listen 8080 default_server;'
        $config = $config -replace 'listen \[::\]:80 default_server;', 'listen [::]:8080 default_server;'
        Set-Content -LiteralPath $nginxConfig -Value $config -NoNewline
        & nginx -g 'daemon off;'
        
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    'setup' {
        & pwsh -NoLogo -NoProfile -File /opt/workspace/setup-llm/scripts/setup.ps1 @RemainingArgument
        
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    'pwsh' {
        & pwsh -NoLogo @RemainingArgument
        
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
