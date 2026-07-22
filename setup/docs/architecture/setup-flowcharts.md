---
title: Setup Flowcharts
sidebar_position: 4
description: Docusaurus-compatible Mermaid diagrams for the setup workflows.
---

# Setup Workflow Flowcharts and Diagrams

**Visual representations of the three-phase setup process defined in the [setup specification](./setup-specification.md).**

---

## 1. Overall Setup Process Flow

```mermaid
graph TD
    Start["🚀 Start New Project"] --> Phase1{Phase 1:<br/>Workstation Setup}
    
    Phase1 -->|First Time?| P1A["Run setup.ps1<br/>- Install prerequisites<br/>- Setup MCP servers<br/>- Configure clients"]
    Phase1 -->|Already Done| P1B["Skip to Phase 2"]
    
    P1A --> P1Check{"Validation:<br/>MCP tools<br/>available?"}
    P1Check -->|No| P1Fail["❌ Troubleshoot<br/>(see Section 8)"]
    P1Check -->|Yes| P1Success["✓ Phase 1 Complete"]
    
    P1B --> P1Success
    P1Fail --> P1A
    
    P1Success --> Phase2["📁 Phase 2:<br/>Project Creation"]
    
    Phase2 --> P2A["Create directory<br/>Initialize Git"]
    P2A --> P2B["Run setup-project.ps1<br/>- Create structure<br/>- Generate files"]
    P2B --> P2C["Review & customize:<br/>README.md<br/>CLAUDE.md<br/>AGENTS.md"]
    
    P2C --> P2Check{"Validation:<br/>Project builds<br/>& tests pass?"}
    P2Check -->|No| P2Fix["Fix issues"]
    P2Fix --> P2B
    P2Check -->|Yes| P2Success["✓ Phase 2 Complete"]
    
    P2Success --> Phase3["🎯 Phase 3:<br/>First Run"]
    
    Phase3 --> ClientChoice{Choose Client}
    
    ClientChoice -->|Claude Code| P3A["Open with 'claude'<br/>Run /init<br/>Run /context<br/>Run /memory"]
    ClientChoice -->|Codex| P3B["Run 'codex'<br/>Verify /mcp<br/>Check tools"]
    ClientChoice -->|Desktop| P3C["Open Cowork<br/>Connect folder<br/>Read docs first"]
    
    P3A --> P3Success["✓ Phase 3 Complete"]
    P3B --> P3Success
    P3C --> P3Success
    
    P3Success --> Done["✅ Ready to Code!"]
    
    style Start fill:#90EE90
    style Done fill:#90EE90
    style Phase1 fill:#87CEEB
    style Phase2 fill:#87CEEB
    style Phase3 fill:#87CEEB
    style P1Fail fill:#FFB6C6
    style P1Success fill:#98FB98
    style P2Success fill:#98FB98
    style P3Success fill:#98FB98
```

---

## 2. Phase 1: Workstation Setup Detailed Flow

```mermaid
graph TD
    P1Start["Phase 1: Workstation Setup"] --> Check["Check Prerequisites"]
    
    Check --> CheckPS["Supported PowerShell?<br/>Windows 5.1+ or pwsh 7+"]
    CheckPS -->|No| FailPS["❌ Install PowerShell"]
    FailPS --> End1["Retry from Check"]
    
    CheckPS -->|Yes| CheckGit["Git installed?"]
    CheckGit -->|No| FailGit["❌ Install Git"]
    FailGit --> End2["Retry from Check"]
    
    CheckGit -->|Yes| CheckDocker["Docker running?"]
    CheckDocker -->|No| FailDocker["❌ Start Docker Desktop or Engine"]
    FailDocker --> End3["Retry from Check"]
    
    CheckDocker -->|Yes| RunSetup["Run setup.ps1"]
    
    RunSetup --> InputParams["Input Parameters:<br/>-Client [Both|Code|Codex]<br/>-IncludeFilesystem [yes/no]<br/>-FilesystemPath [path]"]
    
    InputParams --> InstallComponents["Install Components"]
    
    InstallComponents --> ICmd["1. Validate CLI tools"]
    ICmd --> IGithub["2. Setup GitHub MCP<br/>(reads GITHUB_PERSONAL_ACCESS_TOKEN)"]
    IGithub --> IPlaywright["3. Setup Playwright MCP"]
    IPlaywright --> IFilesystem{Filesystem<br/>enabled?}
    
    IFilesystem -->|No| IGraphify["4. Setup Graphify"]
    IFilesystem -->|Yes| IFSMcp["4a. Setup Filesystem MCP<br/>(config allowed root)"]
    IFSMcp --> IGraphify
    
    IGraphify --> IMemory["5. Setup Claude Memory"]
    IMemory --> RegClients["Register with Clients"]
    
    RegClients --> RegCode["Claude Code:<br/>Load MCP config"]
    RegCode --> RegCodex["Codex:<br/>Load MCP config"]
    
    RegCodex --> RegDesktop{Desktop<br/>enabled?}
    RegDesktop -->|No| Validate["Validation"]
    RegDesktop -->|Yes| RegDeskMCP["Claude Desktop:<br/>Load MCP config"]
    RegDeskMCP --> Validate
    
    Validate --> ValTest1["Test git --version"]
    ValTest1 --> ValTest2["Test docker ps"]
    ValTest2 --> ValTest3["Test /mcp in Codex"]
    ValTest3 --> ValTest4["Test GitHub MCP"]
    
    ValTest4 --> AllPass{All checks<br/>pass?}
    AllPass -->|No| Troubleshoot["⚠️ Troubleshoot<br/>(see schema troubleshooting)"]
    Troubleshoot --> RunSetup
    
    AllPass -->|Yes| P1Done["✓ Phase 1 Complete"]
    P1Done --> RestartNote["⚠️ Restart clients<br/>to load MCP updates"]
    
    style P1Start fill:#87CEEB
    style P1Done fill:#98FB98
    style Troubleshoot fill:#FFD700
    style FailPS fill:#FFB6C6
    style FailGit fill:#FFB6C6
    style FailDocker fill:#FFB6C6
```

---

## 3. Phase 2: Project Creation Detailed Flow

```mermaid
graph TD
    P2Start["Phase 2: Project Creation"] --> ValidatePath["Validate ProjectPath"]
    
    ValidatePath --> CheckFSRoot["Is path under<br/>Filesystem MCP root?"]
    CheckFSRoot -->|No| PathError["❌ Move to allowed root<br/>or re-run setup"]
    PathError --> ValidatePath
    
    CheckFSRoot -->|Yes| CheckExists["Project already<br/>exists?"]
    CheckExists -->|Yes| ExistsError["❌ Choose different path"]
    ExistsError --> ValidatePath
    
    CheckExists -->|No| CreateDirs["Create Directory Structure"]
    
    CreateDirs --> CreateRoot["mkdir ProjectPath"]
    CreateRoot --> CreateSrc["mkdir src/"]
    CreateSrc --> CreateTests["mkdir tests/"]
    CreateTests --> CreateDocs["mkdir docs/decisions/"]
    CreateDocs --> CreateGithub["mkdir .github/"]
    
    CreateGithub --> GenFiles["Generate Project Files"]
    
    GenFiles --> GenGitignore[".gitignore<br/>(secrets, build, IDE)"]
    GenGitignore --> GenEnvExample[".env.example<br/>(template with placeholders)"]
    GenEnvExample --> GenReadme["README.md<br/>(scaffolded with language cmds)"]
    GenReadme --> GenArch["docs/architecture.md<br/>(template)"]
    GenArch --> GenADR["docs/decisions/0001-*.md<br/>(ADR template)"]
    
    GenADR --> GenInstructions["Generate Client Instructions"]
    
    GenInstructions --> ClientCheck{Clients<br/>enabled?}
    
    ClientCheck -->|Code| GenClaude["Generate CLAUDE.md<br/>- Commands for language<br/>- Architecture principles<br/>- Workflow rules<br/>- MCP tools list"]
    ClientCheck -->|Codex| GenAgents["Generate AGENTS.md<br/>- Commands for language<br/>- Architecture principles<br/>- Workflow rules<br/>- MCP tools list"]
    
    GenClaude --> GenAgents
    GenAgents --> GitInit["Initialize Git Repository"]
    
    GitInit --> GitCheck{-SkipGit flag?}
    GitCheck -->|Yes| SkipGit["Skip Git init"]
    GitCheck -->|No| DoGitInit["git init"]
    
    DoGitInit --> GitConfig["Configure Git<br/>user.name & user.email"]
    GitConfig --> GitKeep["Create .gitkeep<br/>in src/ and tests/"]
    
    GitKeep --> Customize["User: Review & Customize"]
    
    Customize --> EditReadme["✏️ Edit README.md<br/>- Add prerequisites<br/>- Add setup steps<br/>- Document build/test/run"]
    EditReadme --> EditInstructions["✏️ Edit CLAUDE.md/AGENTS.md<br/>- Refine commands<br/>- Add architecture notes<br/>- Adjust rules for project"]
    EditInstructions --> EditArch["✏️ Edit docs/architecture.md<br/>- Document components<br/>- Add data flow"]
    
    EditArch --> CreateLangFiles["Create Language-Specific Files<br/>(package.json, requirements.txt, etc.)"]
    
    CreateLangFiles --> BuildTest["Build & Test Project"]
    
    BuildTest --> Build["Run: [build command]"]
    Build --> BuildPass{Build<br/>succeeds?}
    
    BuildPass -->|No| BuildFix["❌ Fix build errors"]
    BuildFix --> Build
    
    BuildPass -->|Yes| Test["Run: [test command]"]
    Test --> TestPass{Tests<br/>pass?}
    
    TestPass -->|No| TestFix["❌ Fix test failures"]
    TestFix --> Test
    
    TestPass -->|Yes| Commit["Initial Git Commit"]
    
    Commit --> GitAdd["git add ."]
    GitAdd --> GitCommit['git commit -m<br/>"Initial project scaffold"']
    
    GitCommit --> P2Done["✓ Phase 2 Complete"]
    
    style P2Start fill:#87CEEB
    style P2Done fill:#98FB98
    style Customize fill:#FFFACD
    style BuildFix fill:#FFD700
    style TestFix fill:#FFD700
    style PathError fill:#FFB6C6
    style ExistsError fill:#FFB6C6
```

---

## 4. Phase 3: First Run Workflows

### 4.1 Claude Code First Run

```mermaid
graph TD
    C1Start["First Run: Claude Code"] --> C1Nav["Set-Location ProjectPath"]
    
    C1Nav --> C1Launch["claude"]
    C1Launch --> C1Verify["Verify instructions loaded"]
    
    C1Verify --> C1Init{CLAUDE.md<br/>exists?}
    C1Init -->|No| C1GenInit["Run: /init<br/>(auto-generate CLAUDE.md)"]
    C1GenInit --> C1Review["Review & edit<br/>generated instructions"]
    C1Review --> C1Commit["Commit to Git"]
    
    C1Init -->|Yes| C1Context["Run: /context<br/>(confirm loaded)"]
    C1Commit --> C1Context
    
    C1Context --> C1Memory["Run: /memory<br/>(inspect settings)"]
    C1Memory --> C1MCPList["Check MCP list:<br/>github ✓<br/>playwright ✓<br/>filesystem ✓"]
    
    C1MCPList --> C1Graphify{Enough<br/>source code?}
    C1Graphify -->|No| C1Ready["Ready for work"]
    C1Graphify -->|Yes| C1RunGraphify["Run: /graphify .<br/>(index repository)"]
    C1RunGraphify --> C1Ready
    
    C1Ready --> C1Prompt["Initial Prompt:<br/>Read CLAUDE.md, README.md<br/>Inspect repository<br/>Explain architecture<br/>Suggest next task"]
    
    C1Prompt --> C1Done["✓ Claude Code Ready"]
    
    style C1Start fill:#87CEEB
    style C1Done fill:#98FB98
    style C1Review fill:#FFFACD
    style C1GenInit fill:#FFD700
```

### 4.2 Codex First Run

```mermaid
graph TD
    X1Start["First Run: Codex"] --> X1Method{Codex CLI<br/>or Desktop?}
    
    X1Method -->|CLI| X1CLI["Set-Location ProjectPath<br/>codex"]
    X1Method -->|Desktop| X1Desktop["Open project as<br/>task workspace<br/>Create new task"]
    
    X1CLI --> X1Verify["Verify AGENTS.md<br/>auto-discovered"]
    X1Desktop --> X1Verify
    
    X1Verify --> X1MCP["Run: /mcp<br/>or /mcp verbose"]
    
    X1MCP --> X1MCPCheck{"All MCP tools<br/>loaded?"}
    X1MCPCheck -->|No| X1Restart["Restart Codex<br/>Start new session"]
    X1Restart --> X1MCP
    
    X1MCPCheck -->|Yes| X1Read["Ask Codex:<br/>Read AGENTS.md & README.md"]
    X1Read --> X1Inspect["Ask Codex:<br/>Inspect repository<br/>without editing"]
    
    X1Inspect --> X1Plan["Ask Codex:<br/>Explain architecture<br/>List build/test/run cmds<br/>Show Git status<br/>Identify next task"]
    
    X1Plan --> X1Flag["Codex flags:<br/>Contradictions?<br/>Missing docs?"]
    
    X1Flag --> X1Done["✓ Codex Ready"]
    
    style X1Start fill:#87CEEB
    style X1Done fill:#98FB98
    style X1Restart fill:#FFD700
```

### 4.3 Claude Desktop (Cowork) First Run

```mermaid
graph TD
    D1Start["First Run: Claude Desktop"] --> D1Open["Open Claude Desktop"]
    
    D1Open --> D1Mode["Select Cowork mode"]
    D1Mode --> D1Task["Create new task"]
    
    D1Task --> D1Grant["Explicitly grant access to<br/>ProjectPath"]
    
    D1Grant --> D1GrantShow["Review folder access<br/>shown by Claude"]
    
    D1GrantShow --> D1Allow["Allow folder access"]
    D1Allow --> D1Init["Initial prompt:<br/>Work inside connected folder<br/>Read README.md, CLAUDE.md<br/>Read docs/architecture.md"]
    
    D1Init --> D1Review["User reviews<br/>Claude's analysis"]
    
    D1Review --> D1Proceed["User authorizes<br/>edits"]
    
    D1Proceed --> D1Done["✓ Claude Desktop Ready"]
    
    style D1Start fill:#87CEEB
    style D1Done fill:#98FB98
    style D1GrantShow fill:#FFFACD
    style D1Allow fill:#FFD700
```

---

## 5. Dependency & Component Graph

```mermaid
graph TB
    WS["🖥️ Workstation"]
    
    WS --> Phase1["Phase 1<br/>setup.ps1"]
    
    Phase1 --> Prerequisites["Prerequisites<br/>Git, Docker,<br/>Node.js, Python"]
    Phase1 --> MCPServers["MCP Servers"]
    Phase1 --> Clients["Clients"]
    
    MCPServers --> GitHub["GitHub MCP"]
    MCPServers --> Playwright["Playwright MCP"]
    MCPServers --> Filesystem["Filesystem MCP"]
    MCPServers --> Graphify["Graphify"]
    MCPServers --> Memory["Claude Memory"]
    
    Clients --> Claude["Claude Code"]
    Clients --> Codex["Codex"]
    Clients --> Desktop["Claude Desktop"]
    
    GitHub --> ProjectCreation["Phase 2<br/>Project Creation"]
    Filesystem --> ProjectCreation
    
    ProjectCreation --> Structure["Directory Structure<br/>src/, tests/,<br/>docs/decisions/"]
    ProjectCreation --> Files["Project Files<br/>README.md,<br/>CLAUDE.md,<br/>AGENTS.md"]
    ProjectCreation --> Git["Git Repository<br/>.gitignore,<br/>Initial commit"]
    
    Files --> FirstRun["Phase 3<br/>First Run"]
    Structure --> FirstRun
    Git --> FirstRun
    
    Claude --> FirstRun
    Codex --> FirstRun
    Desktop --> FirstRun
    
    FirstRun --> Ready["✅ Project Ready<br/>Build, Test, Code"]
    
    style WS fill:#E6E6FA
    style Phase1 fill:#87CEEB
    style ProjectCreation fill:#87CEEB
    style FirstRun fill:#87CEEB
    style Ready fill:#90EE90
    style Prerequisites fill:#F0F8FF
    style MCPServers fill:#F0F8FF
    style Clients fill:#F0F8FF
```

---

## 6. Troubleshooting Decision Tree

```mermaid
graph TD
    Issue["❌ Something Failed"] --> Phase{Which Phase?}
    
    Phase -->|Phase 1| P1Issue["Workstation Setup"]
    Phase -->|Phase 2| P2Issue["Project Creation"]
    Phase -->|Phase 3| P3Issue["First Run"]
    
    P1Issue --> P1Q1{"MCP tools<br/>missing?"}
    P1Q1 -->|Yes| P1A1["✓ Restart client<br/>or start new session"]
    P1Q1 -->|No| P1Q2{"GitHub MCP<br/>fails?"}
    
    P1Q2 -->|Yes| P1A2["✓ Verify Docker running<br/>✓ Check GITHUB_PERSONAL_ACCESS_TOKEN"]
    P1Q2 -->|No| P1Q3{"Setup script<br/>errors?"}
    
    P1Q3 -->|Yes| P1A3["✓ Run platform setup<br/>✓ Verify Docker Desktop or Engine"]
    P1Q3 -->|No| P1Q4{"Filesystem MCP<br/>cannot access?"}
    
    P1Q4 -->|Yes| P1A4["✓ Move project to allowed root<br/>✓ Re-run setup.ps1"]
    P1Q4 -->|No| P1End["Contact support"]
    
    P2Issue --> P2Q1{"Path doesn't<br/>exist?"}
    P2Q1 -->|Yes| P2A1["✓ Check ProjectPath parameter<br/>✓ Verify under Filesystem root"]
    P2Q1 -->|No| P2Q2{"Build fails?"}
    
    P2Q2 -->|Yes| P2A2["✓ Install language tools<br/>✓ Check dependencies<br/>✓ Review error output"]
    P2Q2 -->|No| P2Q3{"Tests fail?"}
    
    P2Q3 -->|Yes| P2A3["✓ Implement test stubs<br/>✓ Fix test configuration"]
    P2Q3 -->|No| P2Q4{"Secret in<br/>Git?"}
    
    P2Q4 -->|Yes| P2A4["✓ Remove from Git history<br/>✓ Rotate secret<br/>✓ Verify .gitignore"]
    P2Q4 -->|No| P2End["Contact support"]
    
    P3Issue --> P3Q1{"Instructions<br/>not loaded?"}
    P3Q1 -->|Yes| P3A1["✓ Verify exact filename<br/>(AGENTS.md, CLAUDE.md)<br/>✓ Opened at repo root"]
    P3Q1 -->|No| P3Q2{"MCP list<br/>incomplete?"}
    
    P3Q2 -->|Yes| P3A2["✓ Restart client<br/>✓ Check Phase 1 setup"]
    P3Q2 -->|No| P3Q3{"Graph stale?"}
    
    P3Q3 -->|Yes| P3A3["✓ Run /graphify . again<br/>✓ After major refactors"]
    P3Q3 -->|No| P3End["Contact support"]
    
    style Issue fill:#FFB6C6
    style P1End fill:#FFB6C6
    style P2End fill:#FFB6C6
    style P3End fill:#FFB6C6
    style P1A1 fill:#98FB98
    style P1A2 fill:#98FB98
    style P1A3 fill:#98FB98
    style P1A4 fill:#98FB98
    style P2A1 fill:#98FB98
    style P2A2 fill:#98FB98
    style P2A3 fill:#98FB98
    style P2A4 fill:#98FB98
    style P3A1 fill:#98FB98
    style P3A2 fill:#98FB98
    style P3A3 fill:#98FB98
```

---

## 7. File Lifecycle

```mermaid
sequenceDiagram
    participant User
    participant setup
    participant setup-project
    participant Git
    participant Client
    
    User->>setup: Run (Phase 1)
    setup->>setup: Install MCP servers
    setup->>setup: Register with clients
    
    User->>setup-project: Run (Phase 2)
    setup-project->>setup-project: Create directories
    setup-project->>setup-project: Generate .gitignore
    setup-project->>setup-project: Generate README.md
    setup-project->>setup-project: Generate CLAUDE.md/AGENTS.md
    setup-project->>Git: git init
    setup-project->>Git: git config
    
    User->>User: Edit README.md<br/>Edit CLAUDE.md/AGENTS.md<br/>Create language files
    
    User->>setup-project: Build & test
    setup-project->>setup-project: npm run build (example)
    setup-project->>setup-project: npm test (example)
    
    User->>Git: git add .
    User->>Git: git commit<br/>"Initial scaffold"
    
    User->>Client: claude / codex / Cowork
    Client->>Client: Load CLAUDE.md / AGENTS.md
    Client->>Client: Load MCP tools
    
    Client-->>User: ✅ Ready for development
```

---

## 8. Success Criteria Checklist

```mermaid
mindmap
  root((✅ Setup Complete))
    Phase 1: Workstation
      Prerequisites verified
      MCP servers installed
      Clients registered
      /mcp shows tools
    Phase 2: Project
      Structure created
      Files generated
      Git initialized
      Builds succeed
      Tests pass
      Initial commit made
    Phase 3: First Run
      Instructions loaded
      /context verified
      /memory accessible
      Client runs
      Graphify indexed
      Ready to code
```

---

## References

- [Setup specification](./setup-specification.md) — Complete specification document
- **setup.ps1** — Phase 1 workstation setup script
- **setup-project.ps1** — Phase 2 & 3 project creation script
- `config/setup-schema.json` — Configuration schema
- `config/setup-config.example.yaml` — Example configuration
