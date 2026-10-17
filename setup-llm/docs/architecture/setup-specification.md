---
title: Setup Specification
sidebar_position: 3
description: Functional specification for workstation setup and first-run client workflows.
---

# Setup Scripts Specification

**Document Version:** 1.0  
**Last Updated:** 2026-07-22  
**Status:** Active  

## 1. Overview

This specification defines the requirements and workflow for preparing a workstation for AI-assisted development with the setup scripts in this directory. Creating a project (its structure, starter files and GitHub repository) is owned by `scripts/New-Project.ps1` in [SubZeroDev.GitHub](https://github.com/The-Running-Dev/SubZeroDev.GitHub).

## 2. Setup Process Phases

### Phase 1: One-Time Workstation Setup
**Trigger:** Fresh development workstation or first-time setup  
**Frequency:** Once per workstation  
**Responsibility:** `setup.ps1`

### Phase 2: New Project Creation
**Trigger:** Starting a new project  
**Frequency:** Per project  
**Responsibility:** `scripts/New-Project.ps1` in [SubZeroDev.GitHub](https://github.com/The-Running-Dev/SubZeroDev.GitHub)

### Phase 3: Project Initialization
**Trigger:** First time opening a project with Claude Code, Codex, or Claude Desktop  
**Frequency:** Per project  
**Responsibility:** Manual (user via CLI or IDE)

---

## 3. Phase 1: Workstation Setup (`setup.ps1`)

### 3.1 Prerequisites

Before running the setup script, verify:

- **Operating System:** Windows, macOS, or an Ubuntu/Debian-derived Linux distribution
- **PowerShell:** Windows PowerShell 5.1+ on Windows, or PowerShell 7+ on any supported OS
- **Package manager:** Winget (Windows), Homebrew (macOS), or apt/pipx (Ubuntu/Debian)
- **Docker:** Docker Desktop or Docker Engine installed and running when GitHub MCP or local workflow testing is used
- **Git:** Installed and available in PATH
- **Node.js:** Installed (required by some MCP servers)
- **Python:** Installed (optional, for some tools)

**Platform scripts:** `setup-windows.ps1`, `setup-macos.ps1`, and `setup-ubuntu.ps1`

### 3.2 Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Client` | Enum | No | `Both` | Target clients: `Both`, `ClaudeCode`, or `Codex` |
| `-IncludeFilesystem` | Switch | No | $false | Enable Filesystem MCP for project access |
| `-FilesystemPath` | String[] | Conditional | — | One or more roots for Filesystem MCP; required with `-IncludeFilesystem` |
| `-SkipGraphify` | Switch | No | $false | Skip Graphify and its `uv` prerequisite |
| `-SkipClaudeMem` | Switch | No | $false | Skip optional third-party `claude-mem` |
| `-SkipGitHub` | Switch | No | $false | Skip GitHub CLI and GitHub MCP setup |
| `-SkipPlaywright` | Switch | No | $false | Skip Playwright MCP registration |
| `-IncludeContext7` | Switch | No | $false | Register the optional Context7 MCP profile |
| `-IncludeDockerMcp` | Switch | No | $false | Register the optional Docker MCP profile |
| `-IncludeDatabase` | Switch | No | $false | Register a separately reviewed database MCP server |

### 3.3 Installation Components

The setup script installs and configures:

| Component | Purpose | Registration | Auto-run |
|-----------|---------|--------------|----------|
| **Command-line prerequisites** | Node.js, selected clients, GitHub CLI, act, and uv | Platform package manager | Yes |
| **Graphify** | Repository knowledge graph indexing | Claude Code, Codex | Yes |
| **Claude Memory** | Persistent memory system (claude-mem) | Claude Code, Codex | Yes |
| **GitHub MCP** | GitHub API access via Docker | Claude Code, Codex | Yes |
| **Playwright MCP** | Browser automation | Claude Code, Codex | Yes |
| **Context7 MCP** | Documentation and library context retrieval | Claude Code, Codex | Optional |
| **Docker MCP** | Docker control and inspection | Claude Code, Codex | Optional |

## Container Architecture

`setup-llm/Dockerfile` is a multi-stage build. The build stage installs PowerShell, synchronizes `setup-llm/docs` into the pinned Docusaurus submodule, installs the locked frontend dependencies, and generates the static site. The runtime stage contains PowerShell, the setup source, nginx, and only the generated site output needed for documentation serving.

`setup-llm/entrypoint.ps1` is the PowerShell entry point and exposes three modes:

| Mode | Behavior |
|------|----------|
| `docs` | Default; serves the prebuilt site through nginx on port 8080 |
| `setup` | Forwards remaining arguments to the cross-platform `setup-llm/scripts/setup.ps1` dispatcher |
| `pwsh` | Starts PowerShell for direct inspection or script execution |

Container setup is isolated from the host. `/root/.config` and `/workspace` are declared as persistence points. Docker-based MCP integrations require an explicit host socket mount, which grants the container control of the host Docker daemon.

MCP registrations live on a separate MCP tool plane from the model gateway. The setup flow only wires approved tools and profile registrations; it does not grant those tools access to model routing credentials or private provider endpoints.

The GitHub workflow validates the documentation and container independently. Pull requests produce a downloadable OCI archive without publishing it. On `main`, the workflow also authenticates with `GITHUB_TOKEN` and publishes SHA and `latest` image tags to GitHub Container Registry.
| **Filesystem MCP** | Local file system access | Claude Code, Codex | Conditional |

### 3.4 Output & Configuration

After successful execution:

- Command-line tools are verified and available in PATH
- MCP server configurations are written to:
  - **Claude Code:** `~/.anthropic/claude-code-config.json` (or equivalent)
  - **Codex:** Local MCP registrations
- Environment variables set in `.env`:
  - `GITHUB_PERSONAL_ACCESS_TOKEN` (read from `$EnvFile`)
  - `FILESYSTEM_ALLOWED_ROOT` (if Filesystem MCP enabled)

### 3.5 Post-Installation Steps

After running the setup script:

1. Restart Claude Code and Codex (or start new sessions) to load MCP registrations
2. Verify MCP tools are available: run `/mcp` in Codex or check MCP list in Claude Code
3. Confirm GitHub MCP is functional: Docker Desktop or Docker Engine must remain running

---

## 4. First-Run Workflows

### 4.1 First Run: Claude Code

**Prerequisites:**
- Workstation setup complete
- Project created with `New-Project.ps1` from [SubZeroDev.GitHub](https://github.com/The-Running-Dev/SubZeroDev.GitHub)
- CLAUDE.md exists and is reviewed

**Steps:**

1. Open PowerShell in project root: `Set-Location 'D:\Dropbox\Projects\MyProject'`
2. Launch Claude Code: `claude`
3. Run `/init` if CLAUDE.md does not exist (generate and review before committing)
4. Run `/context` to confirm instructions loaded
5. Run `/memory` to inspect memory settings
6. Verify MCP tools: Check MCP list for `github`, `playwright`, `filesystem`
7. Run `/graphify .` if repository has sufficient source code

**Suggested initial prompt:**

```
Read CLAUDE.md, README.md, and the architecture notes.
Inspect the repository without editing.
Tell me:
- How to build, test, and run the project
- The main components and their relationships
- Missing setup documentation
- The smallest useful next implementation task
```

### 4.2 First Run: Codex

#### Codex CLI

1. Open PowerShell in project root: `Set-Location 'D:\Dropbox\Projects\MyProject'`
2. Launch Codex CLI: `codex`
3. Verify MCP tools: Run `/mcp` or `/mcp verbose`

#### Codex Desktop

1. Open project folder as task workspace
2. Create a new task; Codex auto-discovers `AGENTS.md`
3. Run `/mcp` or `/mcp verbose` to confirm MCP tools loaded

**Steps for both:**

1. Ask Codex to read `AGENTS.md` and `README.md`
2. Request repository orientation without editing
3. Explain the architecture and build/test/run commands
4. Identify the smallest useful next task

**Suggested initial prompt:**

```
Read AGENTS.md and README.md.
Inspect the repository and test setup without editing.
Explain the architecture, exact build/test/run commands, current Git status,
and the smallest useful next task.
Flag contradictions or missing instructions before proposing changes.
```

### 4.3 First Run: Claude Desktop (Cowork)

**Prerequisites:**
- Claude Desktop installed
- Project located under Filesystem MCP allowed root
- CLAUDE.md and README.md exist

**Steps:**

1. Open Claude Desktop
2. Select **Cowork** mode
3. Create a new task
4. Explicitly grant folder access to `D:\Dropbox\Projects\MyProject`
5. Ask Claude to read `README.md`, `CLAUDE.md`, and architecture notes first
6. Review folder access permissions before allowing edits

**Suggested initial prompt:**

```
Work only inside the connected MyProject folder.
Read README.md, CLAUDE.md, AGENTS.md, and docs/architecture.md.
Do not edit yet.
Explain how the project is built, tested, and run.
Identify missing documentation and the safest first task.
```

---

## 5. Validation & Verification

### 5.1 Workstation Setup Validation

After Phase 1 (`setup.ps1`):

```powershell
# Verify command-line tools
git --version
node --version
docker --version

# Verify MCP servers (in Claude Code or Codex)
/mcp                          # List all available MCP tools

# Test GitHub MCP (verify Docker is running)
# In Codex: /github get issue microsoft/vscode 12345
```

---

## 6. Troubleshooting Reference

| Issue | Cause | Resolution |
|-------|-------|-----------|
| **Setup script fails** | Prerequisites missing | Run the matching platform setup script and verify Docker Desktop or Docker Engine is running |
| **MCP tools not visible** | Client not restarted after setup | Restart Claude Code or Codex; start a new Codex session |
| **GitHub MCP fails** | Docker not running or token invalid | Ensure Docker Desktop or Docker Engine is running; verify `GITHUB_PERSONAL_ACCESS_TOKEN` in `.env` |
| **Filesystem MCP cannot access project** | Project not under allowed root | Move project under `FilesystemPath` configured in setup or re-run setup with correct path |
| **Instructions not loading** | Wrong filename or wrong directory | Verify exact filenames (`AGENTS.md`, `CLAUDE.md`) and client was opened at repository root |
| **Graph information stale** | Graphify cache outdated | Re-run `/graphify .` after moving files or major refactoring |
| **Secrets leaked to Git** | `.gitignore` not set before commit | Remove from tracked files and history; rotate secrets; verify `.gitignore` |

---

## 7. File Dependencies & References

### Input Files (Read by Users/Scripts)

- `.env` (from `FilesystemPath`) — Contains `GITHUB_PERSONAL_ACCESS_TOKEN`

### Output Files (Created/Modified by Setup)

- MCP configuration (client-specific: Claude Code config, Codex local registrations)

---

## 8. Success Criteria

A successful setup is achieved when:

✓ Workstation setup complete: `setup.ps1` runs without errors  
✓ MCP tools available: `/mcp` shows `github`, `playwright`, `filesystem` (if enabled)  
✓ First run complete: Claude Code, Codex, or Claude Desktop opened, `/context` or `/mcp` confirmed tools available  

---

## 9. References

- **Workstation setup:** `setup.ps1`
- **Project setup:** `scripts/New-Project.ps1` in [SubZeroDev.GitHub](https://github.com/The-Running-Dev/SubZeroDev.GitHub)
- **Claude Code Documentation:** https://docs.anthropic.com/en/docs/claude-code/getting-started
- **Codex Documentation:** https://learn.chatgpt.com/docs/concepts/customization
- **MCP Protocol:** https://modelcontextprotocol.io/
