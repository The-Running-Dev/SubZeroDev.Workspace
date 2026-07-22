# LLM Workspace Toolkit

This repository contains reusable PowerShell tooling for preparing AI-assisted development workstations and scaffolding new projects for Codex and Claude Code.

## Repository layout

| Path | Purpose |
|------|---------|
| [`setup/`](setup/) | Cross-platform workstation provisioning, MCP registration, and project scaffolding |
| [`setup/docs/`](setup/docs/) | Getting-started guides, architecture, reference material, and setup specifications |
| [`docs-template/`](docs-template/) | Pinned Docusaurus template submodule used to build the documentation site |
| `LLMs.code-workspace` | VS Code workspace definition |

## Quick start

The setup scripts support Windows, macOS, and Ubuntu/Debian. PowerShell automatically detects the current operating system and selects the appropriate package-installation flow.

```powershell
cd setup
./setup.ps1 -Client Both -WhatIf
./setup.ps1 -Client Both -SkipClaudeMem
```

The preview command shows prerequisite actions without installing them. The second command performs workstation setup while omitting the optional third-party `claude-mem` integration.

For prerequisites, security considerations, platform-specific behavior, and all available switches, read the [`setup` guide](setup/README.md).

## Create a project

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

## Documentation

Start with:

- [Setup overview](setup/docs/index.md)
- [Quick start](setup/docs/getting-started/quickstart.md)
- [New-project workflow](setup/docs/getting-started/new-project.md)
- [Architecture](setup/docs/architecture/modular-architecture.md)
- [Setup specification](setup/docs/architecture/setup-specification.md)

The documentation site is assembled from `setup/docs` with `setup/setup-docs.ps1`. GitHub Actions builds the pinned `docs-template` submodule and deploys the result to GitHub Pages after changes merge to `main`.
