---
title: Quick start
sidebar_position: 1
description: Create and open a new AI-assisted project with the shortest supported workflow.
---

# Quick start

**Fast guide to setting up a new AI-assisted project using setup-project.ps1**

## TL;DR

```powershell
cd D:\Projects\LLMs\setup

.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyApp' `
  -ProjectName 'MyApp' `
  -Language 'node' `
  -AutoCommit
```

Done! Navigate to your project and open with Claude Code or Codex.

## Prerequisites

✓ Workstation setup complete (`.\setup.ps1` has been run)  
✓ Git configured (`git config --global user.name "Your Name"`)  
✓ Python/Node.js/etc. installed (for language-specific setup)

## Step-by-Step

### 1. Navigate to Setup Directory

```powershell
cd D:\Projects\LLMs\setup
```

### 2. Run the Setup Script

Choose your language and project location:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyNewProject' `
  -ProjectName 'MyNewProject' `
  -Language 'node'      # or: python, csharp, rust, java, go
```

### 3. Wait for Completion

The script will:
- ✓ Create directory structure
- ✓ Generate common files (README, CLAUDE.md, docs/, etc.)
- ✓ Create language-specific starters (package.json, requirements.txt, etc.)
- ✓ Initialize Git

### 4. Review Generated Files

Navigate to your project:

```powershell
cd D:\Dropbox\Projects\MyNewProject
code .
```

Edit these key files to customize:
- **README.md** — Add project description and setup details
- **CLAUDE.md** or **AGENTS.md** — Customize AI assistant instructions
- **docs/architecture.md** — Document your system design

### 5. Install Dependencies

```powershell
npm install       # for node
pip install -r requirements.txt   # for python
dotnet restore    # for csharp
cargo build       # for rust
```

### 6. Create Initial Commit (Optional)

If not auto-committed:

```powershell
git add .
git commit -m "Initial project scaffold"
```

### 7. Open with AI Assistant

```powershell
# Claude Code
claude

# Codex
codex
```

## Options & Variations

### Auto-Commit (One-Shot Setup)

Automatically validates and commits after setup:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyApp' `
  -ProjectName 'MyApp' `
  -Language 'node' `
  -AutoCommit
```

### Skip Language Starters

If you want to manually create language files:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyApp' `
  -ProjectName 'MyApp' `
  -Language 'node' `
  -SkipLanguageStarter
```

### Skip Build Validation

If dependencies aren't installed yet:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyApp' `
  -ProjectName 'MyApp' `
  -Language 'node' `
  -SkipValidation
```

### Test Mode (WhatIf)

See what would happen without making changes:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\Test' `
  -ProjectName 'Test' `
  -Language 'node' `
  -WhatIf
```

### Skip Git

For projects with existing Git repos:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\ExistingRepo' `
  -ProjectName 'ExistingRepo' `
  -Language 'node' `
  -SkipGit
```

### Specify Git User

Override global Git config:

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\MyApp' `
  -ProjectName 'MyApp' `
  -Language 'node' `
  -GitUserName 'Alice Developer' `
  -GitUserEmail 'alice@example.com'
```

## Supported Languages

| Language | Starter | Package Manager | Commands |
|----------|---------|-----------------|----------|
| Node.js | ✓ | npm | build, test, lint, start |
| Python | ✓ | pip | build, test, lint, run |
| C# | — | dotnet | build, test, lint, run |
| Rust | — | cargo | build, test, lint, run |
| Java | — | maven | build, test, lint, run |
| Go | — | go | build, test, lint, run |

**Note:** "✓" = has starter script. Others work but require manual language-specific setup.

## What Gets Created

After running the script, you'll have:

```
MyNewProject/
├── src/                    # Your source code (empty)
├── tests/                  # Test files (empty)
├── docs/
│   ├── architecture.md     # System design template
│   └── decisions/
│       └── 0001-initial-*.md   # ADR template
├── .github/                # GitHub (empty)
├── README.md               # Project overview
├── CLAUDE.md               # Claude Code instructions
├── AGENTS.md               # Codex instructions
├── .gitignore              # Git ignore rules
├── .env.example            # Environment variables template
├── .git/                   # Git repository
│
├── package.json            # (Node.js only)
├── tsconfig.json           # (Node.js only)
├── .eslintrc.json          # (Node.js only)
│
├── requirements.txt        # (Python only)
├── setup.py                # (Python only)
├── pytest.ini              # (Python only)
└── ...                     # (language-specific files)
```

## First Steps with Claude Code

```powershell
cd D:\Dropbox\Projects\MyNewProject
claude
```

In Claude Code:

1. Read the instructions:
   ```
   /context
   ```

2. Ask Claude to analyze:
   ```
   Read README.md, CLAUDE.md, and docs/architecture.md.
   Tell me the main components and how to build/test/run it.
   ```

3. Start working:
   - Modify files
   - Run tests
   - Ask Claude for help

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Script not found** | Make sure you're in `D:\Projects\LLMs\setup` directory |
| **Git config error** | Run `git config --global user.name 'Your Name' && git config --global user.email 'your@email.com'` |
| **Path already exists** | Choose a different project path or delete the existing directory |
| **Language starter missing** | Normal for some languages. Manually create language-specific files. See [Language starters](../reference/language-starters.md). |
| **Build validation fails** | Install language dependencies first, or use `-SkipValidation` |

For more details, see:
- [Setup specification](../architecture/setup-specification.md) — Complete setup requirements
- [Modular architecture](../architecture/modular-architecture.md) — How the system works
- [Language starters](../reference/language-starters.md) — Creating/extending language support

## Examples

### Example 1: Node.js Web App

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\WebApp' `
  -ProjectName 'WebApp' `
  -Language 'node' `
  -AutoCommit

# Then:
cd D:\Dropbox\Projects\WebApp
npm install
npm start
```

### Example 2: Python Data Science

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\DataAnalysis' `
  -ProjectName 'DataAnalysis' `
  -Language 'python'

# Then:
cd D:\Dropbox\Projects\DataAnalysis
pip install -r requirements.txt
python -m src.main
```

### Example 3: Rust Systems Tool

```powershell
.\setup-project.ps1 `
  -ProjectPath 'D:\Dropbox\Projects\RustTool' `
  -ProjectName 'RustTool' `
  -Language 'rust' `
  -SkipLanguageStarter   # Manually create Cargo.toml

# Then:
cd D:\Dropbox\Projects\RustTool
cargo build --release
cargo test
```

## Next: Full Documentation

- **Setup overview:** [Setup specification](../architecture/setup-specification.md)
- **Architecture diagrams:** [Setup flowcharts](../architecture/setup-flowcharts.md)
- **How it works:** [Modular architecture](../architecture/modular-architecture.md)
- **Creating language starters:** [Language starters](../reference/language-starters.md)

Happy coding! 🚀
