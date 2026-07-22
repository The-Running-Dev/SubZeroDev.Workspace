# LLM Workspace Toolkit

This repository contains reusable PowerShell tooling for preparing AI-assisted development workstations and scaffolding new projects for Codex and Claude Code.

## Documentation

The complete setup documentation is published at **[llms.subzerodev.com](https://llms.subzerodev.com/)**. The links below open the version stored in this repository, so they also work while reviewing a branch before it is deployed.

### Getting Started

- [Quick Start](setup/docs/getting-started/quickstart.md) — create and open a new AI-assisted project with the shortest supported workflow.
- [Start a New Project](setup/docs/getting-started/new-project.md) — follow the complete Claude Desktop, Claude Code, and Codex workflow.
- [Setup Overview](setup/docs/index.md) — understand the combined setup, authentication, integrations, and platform prerequisites. On the published site, this page is available at [the documentation root](https://llms.subzerodev.com/docs/).

### Architecture and Setup Design

- [Modular Architecture](setup/docs/architecture/modular-architecture.md) — understand the workstation and project setup modules.
- [Setup Flowcharts](setup/docs/architecture/setup-flowcharts.md) — review the installation and project-creation flows visually.
- [Setup Specification](setup/docs/architecture/setup-specification.md) — review inputs, outputs, validation, and required project files.
- [Workspace Blueprint](setup/docs/architecture/workspace-blueprint.md) — review the recommended AI development workspace and rollout plan.

### Reference

- [Language Starters](setup/docs/reference/language-starters.md) — use or extend the language-specific project starters.
- [Reflection Mode](setup/docs/reference/reflection-mode.md) — use the guided inquiry prompt for deliberate analysis.

The root README is the canonical documentation index. The remaining documentation source lives in [`setup/docs/`](setup/docs/). Run `setup/docs-local.ps1` to synchronize both into the pinned Docusaurus template and serve them locally with live reload enabled.

To test the same documentation build job used by GitHub Actions, start Docker and run `setup/docs-workflow-local.ps1`. The script uses [`act`](https://nektosact.com/) to execute the workflow's pull-request build job locally; it does not deploy to GitHub Pages.

## Container Usage

The published container includes PowerShell, the setup scripts, and the prebuilt documentation. No host PowerShell installation is required.

```bash
# Serve the documentation at http://localhost:8080
docker run --rm -p 8080:8080 ghcr.io/the-running-dev/llms:latest

# Run the setup inside the container
docker run --rm -it ghcr.io/the-running-dev/llms:latest setup -Client Codex -SkipGitHub

# Open an interactive PowerShell session
docker run --rm -it ghcr.io/the-running-dev/llms:latest pwsh
```

Container setup changes the container environment. Mount `/root/.config` and `/workspace` when configuration or generated projects must persist. See the [container quick start](setup/docs/getting-started/container.md) for volume and Docker-socket examples.

## Repository Layout

| Path | Purpose |
|------|---------|
| [`setup/`](setup/) | Cross-platform workstation provisioning, MCP registration, and project scaffolding |
| [`setup/docs/`](setup/docs/) | Getting-started guides, architecture, reference material, and setup specifications |
| [`docs-template/`](docs-template/) | Pinned Docusaurus template submodule used to build the documentation site |
| `LLMs.code-workspace` | VS Code workspace definition |

## Quick Start

The setup scripts support Windows, macOS, and Ubuntu/Debian. PowerShell automatically detects the current operating system and selects the appropriate package-installation flow.

```powershell
cd setup
./setup.ps1 -Client Both -WhatIf
./setup.ps1 -Client Both -SkipClaudeMem
```

The preview command shows prerequisite actions without installing them. The second command performs workstation setup while omitting the optional third-party `claude-mem` integration.

## Workstation Setup

### Supported Platforms

| Platform | Prerequisite installer | Package tooling |
|----------|------------------------|-----------------|
| Windows | `setup/setup-windows.ps1` | Winget |
| macOS | `setup/setup-macos.ps1` | Homebrew and npm |
| Ubuntu/Debian | `setup/setup-ubuntu.ps1` | apt, pipx, and npm |

Use `setup/setup.ps1` for normal operation. It detects the OS and dispatches to the matching platform script. `setup/setup-workstation.ps1` contains the shared Graphify, memory, and MCP configuration used after platform prerequisites are available.

### Prerequisites

- PowerShell 7 on macOS and Linux; Windows PowerShell 5.1 or PowerShell 7 on Windows
- Winget on Windows, Homebrew on macOS, or `apt-get` plus `sudo` on Ubuntu/Debian
- Docker Desktop or Docker Engine when GitHub MCP is enabled
- A narrowly scoped GitHub personal access token for GitHub MCP

Run the scripts as your normal user. Review package installations and third-party integrations before enabling them.

### Run the Setup

From the repository root, preview platform prerequisite actions:

```powershell
./setup/setup.ps1 -Client Both -WhatIf
```

Recommended first run without third-party session memory:

```powershell
./setup/setup.ps1 -Client Both -SkipClaudeMem
```

The default setup installs or configures Node.js, the selected assistant CLIs, GitHub CLI, `act`, Astral `uv`, Graphify, Claude Code memory support, optional `claude-mem`, GitHub MCP, and Playwright MCP.

Select one or both supported clients:

```powershell
./setup/setup.ps1 -Client Codex
./setup/setup.ps1 -Client ClaudeCode
./setup/setup.ps1 -Client Both
```

Skip optional components when they are not required:

```powershell
./setup/setup.ps1 `
  -Client Both `
  -SkipGraphify `
  -SkipClaudeMem `
  -SkipGitHub `
  -SkipPlaywright
```

### Restrict Filesystem MCP

Filesystem MCP is disabled by default because the assistants already have native file access. When it is required, grant only the smallest practical directory:

```powershell
./setup/setup.ps1 `
  -Client Both `
  -IncludeFilesystem `
  -FilesystemPath '/path/to/project'
```

### Configure a Database Integration

No generic database MCP package is installed. Select and security-review a maintained server first, then provide its installed command explicitly:

```powershell
./setup/setup.ps1 `
  -Client Codex `
  -SkipClaudeMem `
  -IncludeDatabase `
  -DatabaseName 'my-readonly-db' `
  -DatabaseCommand 'the-reviewed-server-command' `
  -DatabaseArgument @('server-specific-argument')
```

Use a read-only development database account. Keep connection strings and passwords out of script arguments, command history, and source control.

### Configure GitHub MCP

Copy the environment template and insert a narrowly scoped token locally:

```powershell
Copy-Item setup/docker/.env.example setup/docker/.env
```

Keep these defensive defaults unless broader access is intentional:

```dotenv
GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_replace_me
GITHUB_READ_ONLY=1
GITHUB_TOOLSETS=context,repos,issues,pull_requests,actions
```

`setup/docker/.env` is git-ignored. Start Docker Desktop on Windows/macOS or Docker Engine on Linux before running GitHub setup. To retry only GitHub MCP after supplying the token:

```powershell
./setup/setup.ps1 `
  -Client Both `
  -SkipGraphify `
  -SkipClaudeMem `
  -SkipPlaywright
```

`GITHUB_READ_ONLY=1` removes mutation tools exposed by enabled toolsets. `GITHUB_TOOLSETS` is a comma-separated allow-list: `context` exposes authenticated-user context, `repos` repository content, `issues` issue data, `pull_requests` review data, and `actions` workflow information. Avoid `all` unless broad access is intentional, and keep the token itself read-only and narrowly scoped as a second layer of protection.

### Individual Installers

The shared setup orchestrator calls focused installers:

- `setup/setup-windows.ps1`
- `setup/setup-macos.ps1`
- `setup/setup-ubuntu.ps1`
- `setup/setup-workstation.ps1`
- `setup/scripts/workstation/install-graphify.ps1`
- `setup/scripts/workstation/install-claude-memory.ps1`
- `setup/scripts/workstation/install-claude-mem.ps1`
- `setup/scripts/workstation/install-github-mcp.ps1`
- `setup/scripts/workstation/install-filesystem-mcp.ps1`
- `setup/scripts/workstation/install-playwright-mcp.ps1`
- `setup/scripts/workstation/install-database-mcp.ps1`

Most component scripts preserve existing registrations. The GitHub installer intentionally replaces the existing `github` registration so it points to the Compose-managed service.

## Create a Project

After workstation setup, scaffold a new project with:

```powershell
./setup/setup-project.ps1 `
  -ProjectPath '/path/to/MyProject' `
  -ProjectName 'MyProject' `
  -Language 'node'
```

Supported command profiles include Node.js, Python, C#, Rust, Java, and Go. Node.js and Python currently include generated language starters.

Useful generator switches include:

- `-Client Both|Code|Codex`
- `-SkipGit`
- `-SkipLanguageStarter`
- `-SkipValidation`
- `-AutoCommit`
- `-WhatIf`

## Troubleshooting

- **Docker CLI exists but the engine is stopped:** start Docker Desktop or the Docker service, wait until `docker info` succeeds, and rerun.
- **GitHub token error:** verify `setup/docker/.env` exists and its token is not the placeholder.
- **New command is not found:** start a new PowerShell session so package-manager PATH changes load.
- **MCP server is not visible:** restart Codex and Claude Code after registration.
- **Fresh-machine preview stops before integrations:** this is expected; `-WhatIf` does not install commands needed to inspect MCP state.

## Build and Serve the Documentation

Initialize the pinned Docusaurus template after cloning:

```powershell
git submodule update --init --recursive
./setup/setup-docs.ps1
```

The synchronization script copies the canonical root README to the Docusaurus `/docs/` index, copies the remaining documentation, and applies the project-owned sidebar and Docusaurus configuration. Do not edit the generated `docs-template` working tree.

Build the synchronized site locally:

```powershell
Set-Location docs-template
npx -y pnpm@9.0.0 install --frozen-lockfile
npx -y pnpm@9.0.0 run build:prod
```

The build output is written to `docs-template/artifacts`. GitHub Actions validates documentation and the OCI container on pull requests, deploys GitHub Pages from `main`, and publishes the container to GHCR from `main`.

For live reload, run:

```powershell
./setup/docs-local.ps1
```

The default address is `http://localhost:3000/`. Use `-Port`, `-HostName`, or `-NoOpen` to change the server behavior, and `-SkipInstall` only when template dependencies are already installed. Stop an older background instance before restarting so the server can claim its port.

To validate the GitHub documentation build locally with Docker and `act`, run:

```powershell
./setup/docs-workflow-local.ps1
```

The first run downloads the runner image and can take several minutes. On Apple Silicon the wrapper requests `linux/amd64`. Use `-ReuseRunnerImage` after the runner image and actions are cached. `act` closely approximates GitHub-hosted runners but does not implement every GitHub Actions feature.

## Security

- Review scripts before running them.
- Keep tokens and credentials out of source control.
- GitHub MCP is configured through the git-ignored `setup/docker/.env` file and defaults to read-only access.
- Grant Filesystem MCP access only to narrowly scoped directories.
- Use development or sanitized databases with read-only accounts for database MCP integrations.
