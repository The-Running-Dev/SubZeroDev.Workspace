#Requires -Version 5.1
<#
.SYNOPSIS
Setup a new AI-assisted project from scratch.

.DESCRIPTION
Orchestrates complete project creation across three phases:
1. Directory structure and common files
2. Language-specific starter files
3. Build validation and initial commit

Follows docs/architecture/setup-specification.md and uses the modular ProjectSetup module.

.PARAMETER ProjectPath
Absolute path where the project will be created. Must be within Filesystem MCP allowed root.

.PARAMETER ProjectName
Display name of the project (used in documentation).

.PARAMETER Language
Programming language: 'node', 'python', 'csharp', 'rust', 'java', 'go'

.PARAMETER Client
Target clients: 'Both', 'Code' (Claude Code), or 'Codex'

.PARAMETER GitUserName
Git user.name for commits (uses system config if not provided)

.PARAMETER GitUserEmail
Git user.email for commits (uses system config if not provided)

.PARAMETER SkipGit
Skip Git initialization (for projects with existing .git)

.PARAMETER SkipLanguageStarter
Skip language-specific starter file generation

.PARAMETER SkipValidation
Skip build/test validation before first commit

.PARAMETER AutoCommit
Automatically create initial commit if validation succeeds

.EXAMPLE
.\setup-project.ps1 -ProjectPath 'D:\Dropbox\Projects\MyApp' -ProjectName 'MyApp' -Language 'node'

.EXAMPLE
.\setup-project.ps1 -ProjectPath 'D:\Dropbox\Projects\Backend' -ProjectName 'Backend' -Language 'csharp' -AutoCommit

.LINK
docs/architecture/setup-specification.md
.LINK
modules/ProjectSetup.psm1
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
    [string]$ProjectPath,

    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [ValidateSet('node', 'python', 'csharp', 'rust', 'java', 'go')]
    [string]$Language,

    [Parameter()]
    [ValidateSet('Both', 'Code', 'Codex')]
    [string]$Client = 'Both',

    [Parameter()][string]$GitUserName,

    [Parameter()][string]$GitUserEmail,

    [Parameter()][switch]$SkipGit,

    [Parameter()][switch]$SkipLanguageStarter,

    [Parameter()][switch]$SkipValidation,

    [Parameter()][switch]$AutoCommit
)

$ErrorActionPreference = 'Stop'

# Import common functions
. (Join-Path $PSScriptRoot 'modules\Common.ps1')

# Import ProjectSetup module
$modulePath = Join-Path $PSScriptRoot 'modules\ProjectSetup.psm1'
if (-not (Test-Path $modulePath)) {
    throw "ProjectSetup module not found: $modulePath"
}
Import-Module $modulePath -Force

# ============================================================================
# Language Command Mapping
# ============================================================================

$languageCommands = @{
    node = @{
        install  = 'npm install'
        build    = 'npm run build'
        test     = 'npm test'
        lint     = 'npm run lint'
        run      = 'npm start'
    }
    python = @{
        install  = 'pip install -r requirements.txt'
        build    = 'python setup.py build'
        test     = 'pytest'
        lint     = 'pylint src/'
        run      = 'python -m src.main'
    }
    csharp = @{
        install  = 'dotnet restore'
        build    = 'dotnet build'
        test     = 'dotnet test'
        lint     = 'dotnet format --verify-no-changes'
        run      = 'dotnet run'
    }
    rust = @{
        install  = 'cargo fetch'
        build    = 'cargo build --release'
        test     = 'cargo test'
        lint     = 'cargo clippy'
        run      = 'cargo run --release'
    }
    java = @{
        install  = 'mvn install'
        build    = 'mvn clean package'
        test     = 'mvn test'
        lint     = 'mvn checkstyle:check'
        run      = 'java -jar target/app.jar'
    }
    go = @{
        install  = 'go mod download'
        build    = 'go build -o bin/app'
        test     = 'go test ./...'
        lint     = 'golangci-lint run'
        run      = 'go run main.go'
    }
}

# ============================================================================
# Validation
# ============================================================================

Write-Step "Validating setup parameters"

# Check if Git is available
Assert-CommandAvailable -Name 'git' -InstallHint 'Install Git and ensure it is in PATH'

# Validate language
if (-not $languageCommands.ContainsKey($Language)) {
    throw "Unsupported language: $Language. Supported: $($languageCommands.Keys -join ', ')"
}

# Check if project path already exists
$ProjectPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath)
if (Test-Path $ProjectPath) {
    throw "Project path already exists: $ProjectPath`nChoose a different path or use an existing project."
}

# Get Git config
if (-not $GitUserName -or -not $GitUserEmail) {
    Write-WarningMessage "Git user config not provided, using system Git config..."
    
    if (-not $GitUserName) {
        try {
            $GitUserName = & git config --global user.name 2>$null
            if ([string]::IsNullOrWhiteSpace($GitUserName)) {
                throw "Git user.name not configured"
            }
        }
        catch {
            throw "Cannot determine Git user.name. Run: git config --global user.name 'Your Name'"
        }
    }
    
    if (-not $GitUserEmail) {
        try {
            $GitUserEmail = & git config --global user.email 2>$null
            if ([string]::IsNullOrWhiteSpace($GitUserEmail)) {
                throw "Git user.email not configured"
            }
        }
        catch {
            throw "Cannot determine Git user.email. Run: git config --global user.email 'your@email.com'"
        }
    }
}

Write-Success "Using Git config: $GitUserName <$GitUserEmail>"

$commands = $languageCommands[$Language]

# ============================================================================
# Phase 1: Create Project Structure
# ============================================================================

if ($PSCmdlet.ShouldProcess($ProjectPath, 'Create project structure')) {
    Write-Step "Creating project structure: $ProjectPath"
    
    # Create root directory
    $null = New-Item -ItemType Directory -Path $ProjectPath -Force -ErrorAction SilentlyContinue
    Write-Success "Created project directory"
    
    # Create subdirectories
    New-ProjectStructure -ProjectPath $ProjectPath
    Write-Success "Created directory structure"
}

# ============================================================================
# Phase 2: Generate Common Project Files
# ============================================================================

if ($PSCmdlet.ShouldProcess($ProjectPath, 'Generate project files')) {
    Write-Step "Generating project files"
    
    # Generate .gitignore
    New-Gitignore -ProjectPath $ProjectPath -Language $Language
    Write-Success "Generated .gitignore"
    
    # Generate .env.example
    New-EnvExample -ProjectPath $ProjectPath
    Write-Success "Generated .env.example"
    
    # Generate README.md
    New-ReadmeFile -ProjectPath $ProjectPath -ProjectName $ProjectName -Commands $commands
    Write-Success "Generated README.md"
    
    # Generate docs/architecture.md
    New-ArchitectureFile -ProjectPath $ProjectPath -ProjectName $ProjectName
    Write-Success "Generated docs/architecture.md"
    
    # Generate ADR template
    New-AdtTemplate -ProjectPath $ProjectPath
    Write-Success "Generated ADR template"
}

# ============================================================================
# Phase 3: Generate Client Instructions
# ============================================================================

if ($PSCmdlet.ShouldProcess($ProjectPath, 'Generate client instructions')) {
    Write-Step "Generating client instructions"
    
    if ($Client -in @('Both', 'Code')) {
        New-ClaudeInstructions -ProjectPath $ProjectPath -ProjectName $ProjectName -Commands $commands
        Write-Success "Generated CLAUDE.md"
    }
    
    if ($Client -in @('Both', 'Codex')) {
        New-AgentsInstructions -ProjectPath $ProjectPath -ProjectName $ProjectName -Commands $commands
        Write-Success "Generated AGENTS.md"
    }
}

# ============================================================================
# Initialize Git Repository
# ============================================================================

if (-not $SkipGit -and $PSCmdlet.ShouldProcess($ProjectPath, 'Initialize Git repository')) {
    Write-Step "Initializing Git repository"
    
    Initialize-ProjectGit -ProjectPath $ProjectPath -UserName $GitUserName -UserEmail $GitUserEmail
    Write-Success "Git repository initialized"
}

# ============================================================================
# Language-Specific Starter Files
# ============================================================================

if (-not $SkipLanguageStarter) {
    Write-Step "Setting up language-specific starter files"
    
    try {
        Invoke-LanguageStarter -Language $Language -ProjectPath $ProjectPath -ProjectName $ProjectName
        Write-Success "Language starter setup complete"
    }
    catch {
        Write-WarningMessage "Language starter setup skipped or failed: $_"
        Write-WarningMessage "You will need to create language-specific files manually"
    }
}

# ============================================================================
# Build Validation
# ============================================================================

if (-not $SkipValidation) {
    Write-Step "Preparing for validation"
    Write-WarningMessage "Build/test validation requires language tools to be installed."
    Write-WarningMessage "If you haven't set up dependencies yet, you can skip validation with -SkipValidation"
    
    $buildSuccess = $false
    $testSuccess = $false
    
    try {
        # Try to build
        $buildSuccess = Test-ProjectBuildable -ProjectPath $ProjectPath -BuildCommand $commands.build
        if ($buildSuccess) {
            Write-Success "Project build succeeded"
        }
    }
    catch {
        Write-WarningMessage "Build validation skipped or failed (may require dependencies to be installed first)"
    }
    
    try {
        # Try to run tests
        if ($buildSuccess) {
            $testSuccess = Test-ProjectTestable -ProjectPath $ProjectPath -TestCommand $commands.test
            if ($testSuccess) {
                Write-Success "Project tests passed"
            }
        }
    }
    catch {
        Write-WarningMessage "Test validation skipped or failed"
    }
}

# ============================================================================
# Initial Commit
# ============================================================================

if ($AutoCommit) {
    Write-Step "Creating initial commit"
    
    try {
        New-ProjectInitialCommit -ProjectPath $ProjectPath
        Write-Success "Initial commit created"
    }
    catch {
        Write-WarningMessage "Automatic commit failed: $_"
        Write-WarningMessage "You will need to commit manually:"
        Write-WarningMessage "  cd '$ProjectPath'"
        Write-WarningMessage "  git add ."
        Write-WarningMessage '  git commit -m "Initial project scaffold"'
    }
}

# ============================================================================
# Summary & Next Steps
# ============================================================================

Write-Step "Project Setup Summary"

Write-Host @"

✓ Project created: $ProjectName
✓ Location: $ProjectPath
✓ Language: $Language
✓ Target clients: $Client

NEXT STEPS:

1. Navigate to your project:
   cd '$ProjectPath'

2. Review and customize the generated files:
   - README.md (add project-specific details)
   - CLAUDE.md or AGENTS.md (refine instructions)
   - docs/architecture.md (document your architecture)

3. Install dependencies:
   $($commands.install)

4. Create language-specific files as needed:
   See docs/architecture.md for guidance

5. Build and test:
   $($commands.build)
   $($commands.test)

6. Make your initial commit (if not auto-committed):
   git add .
   git commit -m "Initial project scaffold"

7. Open with Claude Code or Codex:
   cd '$ProjectPath'
   claude                # For Claude Code
   codex                 # For Codex CLI

For detailed documentation, see:
- docs/architecture/setup-specification.md (overall setup workflow)
- README.md (project overview)
- CLAUDE.md / AGENTS.md (client-specific guidelines)
- docs/architecture.md (system design)

"@ -ForegroundColor Green

Write-Success "Project setup complete!"
