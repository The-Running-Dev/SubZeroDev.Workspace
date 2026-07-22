# LLM Workspace Toolkit

This repository contains reusable PowerShell tooling for preparing AI-assisted development workstations and scaffolding new projects for Codex and Claude Code.

## Documentation

The complete setup documentation is published at **[llms.subzerodev.com](https://llms.subzerodev.com/)**. Use these direct links for quick access:

### Getting Started

- [Quick Start](https://llms.subzerodev.com/docs/getting-started/quickstart) — create and open a new AI-assisted project with the shortest supported workflow.
- [Start a New Project](https://llms.subzerodev.com/docs/getting-started/new-project) — follow the complete Claude Desktop, Claude Code, and Codex workflow.
- [Setup Overview](https://llms.subzerodev.com/docs/template-overview) — understand the combined setup, authentication, integrations, and platform prerequisites.

### Architecture and Setup Design

- [Modular Architecture](https://llms.subzerodev.com/docs/architecture/modular-architecture) — understand the workstation and project setup modules.
- [Setup Flowcharts](https://llms.subzerodev.com/docs/architecture/setup-flowcharts) — review the installation and project-creation flows visually.
- [Setup Specification](https://llms.subzerodev.com/docs/architecture/setup-specification) — review inputs, outputs, validation, and required project files.
- [Workspace Blueprint](https://llms.subzerodev.com/docs/architecture/workspace-blueprint) — review the recommended AI development workspace and rollout plan.

### Reference

- [Language Starters](https://llms.subzerodev.com/docs/reference/language-starters) — use or extend the language-specific project starters.
- [Reflection Mode](https://llms.subzerodev.com/docs/reference/reflection-mode) — use the guided inquiry prompt for deliberate analysis.

The documentation source lives in [`setup/docs/`](setup/docs/). Run `setup/docs-local.ps1` to synchronize it into the pinned Docusaurus template and serve it locally.

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

For prerequisites, security considerations, platform-specific behavior, and all available switches, read the [`setup` guide](setup/README.md).

## Create a Project

After workstation setup, scaffold a new project with:

```powershell
./setup/setup-project.ps1 `
  -ProjectPath '/path/to/MyProject' `
  -ProjectName 'MyProject' `
  -Language 'node'
```

Supported command profiles include Node.js, Python, C#, Rust, Java, and Go. Node.js and Python currently include generated language starters.

## Security

- Review scripts before running them.
- Keep tokens and credentials out of source control.
- GitHub MCP is configured through the git-ignored `setup/docker/.env` file and defaults to read-only access.
- Grant Filesystem MCP access only to narrowly scoped directories.
- Use development or sanitized databases with read-only accounts for database MCP integrations.
