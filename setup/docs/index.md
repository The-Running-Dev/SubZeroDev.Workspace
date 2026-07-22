---
title: AI coding workspace setup
id: template-overview
slug: /
sidebar_position: 1
description: Install and configure shared tooling for Claude Code and Codex on Windows, macOS, and Ubuntu.
---

# AI coding workspace setup

These scripts implement the staged workspace described in the [workspace blueprint](./architecture/workspace-blueprint.md). Run them from PowerShell as your normal user and review every script before execution. Windows supports Windows PowerShell 5.1 or PowerShell 7; macOS and Linux require PowerShell 7.

For the project-by-project workflow, see [Starting a new AI-assisted project](./getting-started/new-project.md).

The combined setup detects the host OS, installs missing command-line prerequisites with the platform package manager, and then runs the shared MCP and assistant configuration. Existing commands are left unchanged.

| Platform | Direct entry point | Package tooling |
|----------|--------------------|-----------------|
| Windows | `setup-windows.ps1` | Winget |
| macOS | `setup-macos.ps1` | Homebrew and npm |
| Ubuntu/Debian | `setup-ubuntu.ps1` | apt, pipx, and npm |

`setup.ps1` is the recommended entry point because it dispatches to the appropriate platform script. The platform entry points are useful for explicit automation and troubleshooting. The shared `setup-workstation.ps1` assumes prerequisites already exist and configures only Graphify, memory, and MCP integrations.

## Combined setup

Preview actions first:

```powershell
.\setup.ps1 -Client Both -WhatIf
```

The platform preview reports prerequisite installation actions and stops before shared integrations, because commands intentionally skipped by `-WhatIf` cannot be used to inspect MCP registration safely.

Install Graphify, check Claude built-in memory, install claude-mem, register the official GitHub MCP server, and register Playwright MCP:

```powershell
.\setup.ps1 -Client Both
```

Recommended first pilot without third-party memory:

```powershell
.\setup.ps1 -Client Both -SkipClaudeMem
```

Include a narrowly scoped filesystem server:

```powershell
.\setup.ps1 `
  -Client Both `
  -SkipClaudeMem `
  -IncludeFilesystem `
  -FilesystemPath '/path/to/MyApp'
```

The filesystem integration is not enabled by default because Codex and Claude Code already have native file access.

## Database integration

No generic database MCP package is installed. Select and security-review a maintained server first, then provide its installed command explicitly:

```powershell
.\setup.ps1 `
  -Client Codex `
  -SkipClaudeMem `
  -IncludeDatabase `
  -DatabaseName 'my-readonly-db' `
  -DatabaseCommand 'the-reviewed-server-command' `
  -DatabaseArgument @('server-specific-argument')
```

Use a read-only development database account. Keep connection strings and passwords out of script arguments, command history, and source control.

## GitHub authentication

GitHub MCP runs through `docker/docker-compose.yml` and reads its settings from the git-ignored `docker/.env` file. Add a narrowly scoped token to `GITHUB_PERSONAL_ACCESS_TOKEN` in `docker/.env` before using the server. The checked-in `docker/.env.example` documents the required variables without containing a real secret.

### GitHub MCP access controls

```dotenv
GITHUB_READ_ONLY=1
GITHUB_TOOLSETS=context,repos,issues,pull_requests,actions
```

`GITHUB_READ_ONLY=1` starts the server in read-only mode. The server omits tools that could modify GitHub data, even when an enabled toolset normally contains write operations. Agents can inspect repositories, issues, pull requests, and workflow activity, but cannot create, edit, merge, comment, dispatch, or delete through this MCP server. Keep the token itself read-only and narrowly scoped as a second layer of protection; this setting does not grant access that the token lacks.

`GITHUB_TOOLSETS` is a comma-separated allow-list of capability groups exposed to the agent. Restricting this list reduces unnecessary tools and context:

- `context` — information about the authenticated GitHub user and the current GitHub context.
- `repos` — repository metadata and content, including files, branches, commits, tags, and releases where supported.
- `issues` — issue details, lists, searches, and comments. Write-oriented issue tools are removed by read-only mode.
- `pull_requests` — pull-request details, changed files, diffs, reviews, comments, and status information. Creation, review submission, merging, and other mutations are removed in read-only mode.
- `actions` — GitHub Actions workflows, runs, jobs, artifacts, and logs where the token permits access. Workflow dispatch and other write actions are removed in read-only mode.

Add another toolset only when its capabilities are required. Avoid `all` unless broad GitHub access is intentional, because it exposes substantially more tools to the agent.

## Individual installers

- `setup-windows.ps1`
- `setup-macos.ps1`
- `setup-ubuntu.ps1`
- `setup-workstation.ps1`
- `scripts/workstation/install-graphify.ps1`
- `scripts/workstation/install-claude-memory.ps1`
- `scripts/workstation/install-claude-mem.ps1`
- `scripts/workstation/install-github-mcp.ps1`
- `scripts/workstation/install-filesystem-mcp.ps1`
- `scripts/workstation/install-playwright-mcp.ps1`
- `scripts/workstation/install-database-mcp.ps1`

Most component scripts preserve existing MCP registrations. The GitHub installer intentionally replaces the existing `github` registration so it points to the Compose-managed service.

## Platform prerequisites

- Windows requires Winget. Docker Desktop must be installed separately for GitHub MCP.
- macOS requires [Homebrew](https://brew.sh). Docker Desktop must be installed and started separately for GitHub MCP.
- Ubuntu/Debian requires `apt-get` and `sudo`. Install Docker Engine or Docker Desktop separately and ensure the current user can run `docker`.

Use `-SkipGraphify`, `-SkipClaudeMem`, `-SkipGitHub`, or `-SkipPlaywright` when a component is not wanted. `-Client Codex` avoids installing or checking Claude Code; `-Client ClaudeCode` does the converse.
