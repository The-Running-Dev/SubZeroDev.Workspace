@{
    RootModule        = 'setup.psm1'
    ModuleVersion     = '0.1.0'
    FunctionsToExport = @(
        'Invoke-DocsLocal'
        'Invoke-DocsWorkflowLocal'
        'Write-Step'
        'Write-Success'
        'Write-WarningMessage'
        'Test-CommandAvailable'
        'Update-SessionPath'
        'Get-NpxCommand'
        'Assert-CommandAvailable'
        'Invoke-NativeCommand'
        'Test-McpServerRegistered'
        'Resolve-OrCreatePath'
        'Invoke-SetupDocs'
        'Invoke-SetupMacos'
        'Invoke-SetupUbuntu'
        'Invoke-SetupWindows'
        'Invoke-SetupWorkstation'
        'Invoke-Setup'
        'Invoke-InstallClaudeMem'
        'Invoke-InstallClaudeMemory'
        'Invoke-InstallDatabaseMcp'
        'Invoke-InstallFilesystemMcp'
        'Invoke-InstallGithubMcp'
        'Invoke-InstallGraphify'
        'Invoke-InstallPlaywrightMcp'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}