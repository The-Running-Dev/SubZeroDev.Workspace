@{
    Id = 'repository.setup'
    GeneratedBy = 'SubZeroDev.ContainerPSGenerator'
    ModuleName = 'setup'
    ModuleVersion = '0.1.0'
    ContainerImage = 'setup'
    Commands = @(
@{
            Id = 'script.scripts.docs-local'
            Name = 'Invoke-DocsLocal'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/docs-local.ps1''.'
            Description = 'Scaffolded from ''scripts/docs-local.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/docs-local.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'SourcePath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from SourcePath.'
                }
@{
                    Name = 'TemplatePath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from TemplatePath.'
                }
@{
                    Name = 'Port'
                    Type = 'Int32'
                    Mandatory = $false
                    Description = 'Discovered from Port.'
                }
@{
                    Name = 'HostName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from HostName.'
                }
@{
                    Name = 'NoOpen'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from NoOpen.'
                }
@{
                    Name = 'SkipInstall'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipInstall.'
                }
            )
        }
@{
            Id = 'script.scripts.docs-workflow-local'
            Name = 'Invoke-DocsWorkflowLocal'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/docs-workflow-local.ps1''.'
            Description = 'Scaffolded from ''scripts/docs-workflow-local.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/docs-workflow-local.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'WorkflowPath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from WorkflowPath.'
                }
@{
                    Name = 'RunnerImage'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from RunnerImage.'
                }
@{
                    Name = 'ReuseRunnerImage'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from ReuseRunnerImage.'
                }
            )
        }
@{
            Id = 'module.setup.write-step'
            Name = 'Write-Step'
            Synopsis = 'Runs the discovered module command ''Write-Step''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Message'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Message.'
                }
            )
        }
@{
            Id = 'module.setup.write-success'
            Name = 'Write-Success'
            Synopsis = 'Runs the discovered module command ''Write-Success''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Message'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Message.'
                }
            )
        }
@{
            Id = 'module.setup.write-warningmessage'
            Name = 'Write-WarningMessage'
            Synopsis = 'Runs the discovered module command ''Write-WarningMessage''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Message'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Message.'
                }
            )
        }
@{
            Id = 'module.setup.test-commandavailable'
            Name = 'Test-CommandAvailable'
            Synopsis = 'Runs the discovered module command ''Test-CommandAvailable''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Name'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Name.'
                }
            )
        }
@{
            Id = 'module.setup.update-sessionpath'
            Name = 'Update-SessionPath'
            Synopsis = 'Runs the discovered module command ''Update-SessionPath''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @()
        }
@{
            Id = 'module.setup.get-npxcommand'
            Name = 'Get-NpxCommand'
            Synopsis = 'Runs the discovered module command ''Get-NpxCommand''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @()
        }
@{
            Id = 'module.setup.assert-commandavailable'
            Name = 'Assert-CommandAvailable'
            Synopsis = 'Runs the discovered module command ''Assert-CommandAvailable''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Name'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Name.'
                }
@{
                    Name = 'InstallHint'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from InstallHint.'
                }
            )
        }
@{
            Id = 'module.setup.invoke-nativecommand'
            Name = 'Invoke-NativeCommand'
            Synopsis = 'Runs the discovered module command ''Invoke-NativeCommand''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'FilePath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from FilePath.'
                }
@{
                    Name = 'ArgumentList'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from ArgumentList.'
                }
            )
        }
@{
            Id = 'module.setup.test-mcpserverregistered'
            Name = 'Test-McpServerRegistered'
            Synopsis = 'Runs the discovered module command ''Test-McpServerRegistered''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'ServerName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ServerName.'
                }
            )
        }
@{
            Id = 'module.setup.resolve-orcreatepath'
            Name = 'Resolve-OrCreatePath'
            Synopsis = 'Runs the discovered module command ''Resolve-OrCreatePath''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Path'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Path.'
                }
@{
                    Name = 'PathKind'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from PathKind.'
                }
            )
        }
@{
            Id = 'module.setup.new-projectstructure'
            Name = 'New-ProjectStructure'
            Synopsis = 'Runs the discovered module command ''New-ProjectStructure''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'Directories'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from Directories.'
                }
            )
        }
@{
            Id = 'module.setup.new-projectfile'
            Name = 'New-ProjectFile'
            Synopsis = 'Runs the discovered module command ''New-ProjectFile''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'RelativePath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from RelativePath.'
                }
@{
                    Name = 'Content'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Content.'
                }
@{
                    Name = 'Force'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from Force.'
                }
            )
        }
@{
            Id = 'module.setup.new-gitignore'
            Name = 'New-Gitignore'
            Synopsis = 'Runs the discovered module command ''New-Gitignore''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'Language'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Language.'
                }
            )
        }
@{
            Id = 'module.setup.new-envexample'
            Name = 'New-EnvExample'
            Synopsis = 'Runs the discovered module command ''New-EnvExample''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
            )
        }
@{
            Id = 'module.setup.new-readmefile'
            Name = 'New-ReadmeFile'
            Synopsis = 'Runs the discovered module command ''New-ReadmeFile''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
@{
                    Name = 'Commands'
                    Type = 'Hashtable'
                    Mandatory = $true
                    Description = 'Discovered from Commands.'
                }
            )
        }
@{
            Id = 'module.setup.new-architecturefile'
            Name = 'New-ArchitectureFile'
            Synopsis = 'Runs the discovered module command ''New-ArchitectureFile''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
            )
        }
@{
            Id = 'module.setup.new-adttemplate'
            Name = 'New-AdtTemplate'
            Synopsis = 'Runs the discovered module command ''New-AdtTemplate''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
            )
        }
@{
            Id = 'module.setup.new-claudeinstructions'
            Name = 'New-ClaudeInstructions'
            Synopsis = 'Runs the discovered module command ''New-ClaudeInstructions''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
@{
                    Name = 'Commands'
                    Type = 'Hashtable'
                    Mandatory = $true
                    Description = 'Discovered from Commands.'
                }
            )
        }
@{
            Id = 'module.setup.new-agentsinstructions'
            Name = 'New-AgentsInstructions'
            Synopsis = 'Runs the discovered module command ''New-AgentsInstructions''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
@{
                    Name = 'Commands'
                    Type = 'Hashtable'
                    Mandatory = $true
                    Description = 'Discovered from Commands.'
                }
            )
        }
@{
            Id = 'module.setup.initialize-projectgit'
            Name = 'Initialize-ProjectGit'
            Synopsis = 'Runs the discovered module command ''Initialize-ProjectGit''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'UserName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from UserName.'
                }
@{
                    Name = 'UserEmail'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from UserEmail.'
                }
@{
                    Name = 'SkipInit'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipInit.'
                }
            )
        }
@{
            Id = 'module.setup.invoke-languagestarter'
            Name = 'Invoke-LanguageStarter'
            Synopsis = 'Runs the discovered module command ''Invoke-LanguageStarter''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'Language'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Language.'
                }
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
            )
        }
@{
            Id = 'module.setup.test-projectbuildable'
            Name = 'Test-ProjectBuildable'
            Synopsis = 'Runs the discovered module command ''Test-ProjectBuildable''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'BuildCommand'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from BuildCommand.'
                }
            )
        }
@{
            Id = 'module.setup.test-projecttestable'
            Name = 'Test-ProjectTestable'
            Synopsis = 'Runs the discovered module command ''Test-ProjectTestable''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'TestCommand'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from TestCommand.'
                }
            )
        }
@{
            Id = 'module.setup.new-projectinitialcommit'
            Name = 'New-ProjectInitialCommit'
            Synopsis = 'Runs the discovered module command ''New-ProjectInitialCommit''.'
            Description = 'Scaffolded from ''scripts/Modules/Setup.psm1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/Modules/Setup.psm1'
            SourceKind = 'ModuleFunction'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'Message'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Message.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-docs'
            Name = 'Invoke-SetupDocs'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-docs.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-docs.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-docs.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'SourcePath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from SourcePath.'
                }
@{
                    Name = 'TemplatePath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from TemplatePath.'
                }
@{
                    Name = 'ReadmePath'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from ReadmePath.'
                }
@{
                    Name = 'OrganizationName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from OrganizationName.'
                }
@{
                    Name = 'RepositoryName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from RepositoryName.'
                }
@{
                    Name = 'SiteTitle'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from SiteTitle.'
                }
@{
                    Name = 'SiteUrl'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from SiteUrl.'
                }
@{
                    Name = 'BaseUrl'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from BaseUrl.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-macos'
            Name = 'Invoke-SetupMacos'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-macos.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-macos.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-macos.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'SkipClaudeMem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipClaudeMem.'
                }
@{
                    Name = 'SkipGitHub'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGitHub.'
                }
@{
                    Name = 'SkipPlaywright'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipPlaywright.'
                }
@{
                    Name = 'SkipGraphify'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGraphify.'
                }
@{
                    Name = 'IncludeFilesystem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeFilesystem.'
                }
@{
                    Name = 'FilesystemPath'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from FilesystemPath.'
                }
@{
                    Name = 'IncludeDatabase'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeDatabase.'
                }
@{
                    Name = 'DatabaseName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseName.'
                }
@{
                    Name = 'DatabaseCommand'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseCommand.'
                }
@{
                    Name = 'DatabaseArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseArgument.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-project'
            Name = 'Invoke-SetupProject'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-project.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-project.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-project.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
@{
                    Name = 'Language'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Language.'
                }
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'GitUserName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from GitUserName.'
                }
@{
                    Name = 'GitUserEmail'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from GitUserEmail.'
                }
@{
                    Name = 'SkipGit'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGit.'
                }
@{
                    Name = 'SkipLanguageStarter'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipLanguageStarter.'
                }
@{
                    Name = 'SkipValidation'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipValidation.'
                }
@{
                    Name = 'AutoCommit'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from AutoCommit.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-ubuntu'
            Name = 'Invoke-SetupUbuntu'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-ubuntu.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-ubuntu.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-ubuntu.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'SkipClaudeMem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipClaudeMem.'
                }
@{
                    Name = 'SkipGitHub'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGitHub.'
                }
@{
                    Name = 'SkipPlaywright'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipPlaywright.'
                }
@{
                    Name = 'SkipGraphify'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGraphify.'
                }
@{
                    Name = 'IncludeFilesystem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeFilesystem.'
                }
@{
                    Name = 'FilesystemPath'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from FilesystemPath.'
                }
@{
                    Name = 'IncludeDatabase'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeDatabase.'
                }
@{
                    Name = 'DatabaseName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseName.'
                }
@{
                    Name = 'DatabaseCommand'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseCommand.'
                }
@{
                    Name = 'DatabaseArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseArgument.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-windows'
            Name = 'Invoke-SetupWindows'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-windows.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-windows.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-windows.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'SkipClaudeMem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipClaudeMem.'
                }
@{
                    Name = 'SkipGitHub'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGitHub.'
                }
@{
                    Name = 'SkipPlaywright'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipPlaywright.'
                }
@{
                    Name = 'SkipGraphify'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGraphify.'
                }
@{
                    Name = 'IncludeFilesystem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeFilesystem.'
                }
@{
                    Name = 'FilesystemPath'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from FilesystemPath.'
                }
@{
                    Name = 'IncludeDatabase'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeDatabase.'
                }
@{
                    Name = 'DatabaseName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseName.'
                }
@{
                    Name = 'DatabaseCommand'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseCommand.'
                }
@{
                    Name = 'DatabaseArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseArgument.'
                }
            )
        }
@{
            Id = 'script.scripts.setup-workstation'
            Name = 'Invoke-SetupWorkstation'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup-workstation.ps1''.'
            Description = 'Scaffolded from ''scripts/setup-workstation.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup-workstation.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'SkipClaudeMem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipClaudeMem.'
                }
@{
                    Name = 'SkipGitHub'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGitHub.'
                }
@{
                    Name = 'SkipPlaywright'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipPlaywright.'
                }
@{
                    Name = 'SkipGraphify'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGraphify.'
                }
@{
                    Name = 'IncludeFilesystem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeFilesystem.'
                }
@{
                    Name = 'FilesystemPath'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from FilesystemPath.'
                }
@{
                    Name = 'IncludeDatabase'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeDatabase.'
                }
@{
                    Name = 'DatabaseName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseName.'
                }
@{
                    Name = 'DatabaseCommand'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseCommand.'
                }
@{
                    Name = 'DatabaseArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseArgument.'
                }
            )
        }
@{
            Id = 'script.scripts.setup'
            Name = 'Invoke-Setup'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/setup.ps1''.'
            Description = 'Scaffolded from ''scripts/setup.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/setup.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
@{
                    Name = 'SkipClaudeMem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipClaudeMem.'
                }
@{
                    Name = 'SkipGitHub'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGitHub.'
                }
@{
                    Name = 'SkipPlaywright'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipPlaywright.'
                }
@{
                    Name = 'SkipGraphify'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from SkipGraphify.'
                }
@{
                    Name = 'IncludeFilesystem'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeFilesystem.'
                }
@{
                    Name = 'FilesystemPath'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from FilesystemPath.'
                }
@{
                    Name = 'IncludeDatabase'
                    Type = 'switch'
                    Mandatory = $false
                    Description = 'Discovered from IncludeDatabase.'
                }
@{
                    Name = 'DatabaseName'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseName.'
                }
@{
                    Name = 'DatabaseCommand'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseCommand.'
                }
@{
                    Name = 'DatabaseArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from DatabaseArgument.'
                }
            )
        }
@{
            Id = 'script.scripts.starters.setup-starter-node'
            Name = 'Invoke-SetupStarterNode'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/starters/setup-starter-node.ps1''.'
            Description = 'Scaffolded from ''scripts/starters/setup-starter-node.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/starters/setup-starter-node.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
            )
        }
@{
            Id = 'script.scripts.starters.setup-starter-python'
            Name = 'Invoke-SetupStarterPython'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/starters/setup-starter-python.ps1''.'
            Description = 'Scaffolded from ''scripts/starters/setup-starter-python.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/starters/setup-starter-python.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'ProjectPath'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectPath.'
                }
@{
                    Name = 'ProjectName'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from ProjectName.'
                }
            )
        }
@{
            Id = 'script.scripts.workstation.install-claude-mem'
            Name = 'Invoke-InstallClaudeMem'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-claude-mem.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-claude-mem.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-claude-mem.ps1'
            SourceKind = 'Script'
            Parameters = @()
        }
@{
            Id = 'script.scripts.workstation.install-claude-memory'
            Name = 'Invoke-InstallClaudeMemory'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-claude-memory.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-claude-memory.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-claude-memory.ps1'
            SourceKind = 'Script'
            Parameters = @()
        }
@{
            Id = 'script.scripts.workstation.install-database-mcp'
            Name = 'Invoke-InstallDatabaseMcp'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-database-mcp.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-database-mcp.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-database-mcp.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Name'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Name.'
                }
@{
                    Name = 'Command'
                    Type = 'String'
                    Mandatory = $true
                    Description = 'Discovered from Command.'
                }
@{
                    Name = 'ServerArgument'
                    Type = 'String[]'
                    Mandatory = $false
                    Description = 'Discovered from ServerArgument.'
                }
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
            )
        }
@{
            Id = 'script.scripts.workstation.install-filesystem-mcp'
            Name = 'Invoke-InstallFilesystemMcp'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-filesystem-mcp.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-filesystem-mcp.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-filesystem-mcp.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'AllowedPath'
                    Type = 'String[]'
                    Mandatory = $true
                    Description = 'Discovered from AllowedPath.'
                }
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
            )
        }
@{
            Id = 'script.scripts.workstation.install-github-mcp'
            Name = 'Invoke-InstallGithubMcp'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-github-mcp.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-github-mcp.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-github-mcp.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
            )
        }
@{
            Id = 'script.scripts.workstation.install-graphify'
            Name = 'Invoke-InstallGraphify'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-graphify.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-graphify.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-graphify.ps1'
            SourceKind = 'Script'
            Parameters = @()
        }
@{
            Id = 'script.scripts.workstation.install-playwright-mcp'
            Name = 'Invoke-InstallPlaywrightMcp'
            Synopsis = 'Runs the discovered PowerShell script ''scripts/workstation/install-playwright-mcp.ps1''.'
            Description = 'Scaffolded from ''scripts/workstation/install-playwright-mcp.ps1''. Review its container invocation mappings before publishing.'
            SourcePath = 'scripts/workstation/install-playwright-mcp.ps1'
            SourceKind = 'Script'
            Parameters = @(
@{
                    Name = 'Client'
                    Type = 'String'
                    Mandatory = $false
                    Description = 'Discovered from Client.'
                }
            )
        }
    )
}
