---
title: Start a New Project
sidebar_position: 2
description: Set up a repository for Claude Desktop, Claude Code, and Codex.
---

# Starting a New AI-Assisted Project

This guide assumes the workspace tooling in this directory has already been installed on Windows, macOS, or Ubuntu/Debian. It covers the shared project setup and the first-run workflow for Claude Desktop, Claude Code, and Codex.

## 1. Install the Workstation Tools Once

Run this from the repository's `setup` directory in PowerShell:

```powershell
.\setup.ps1 `
  -Client Both `
  -IncludeFilesystem `
  -FilesystemPath '/path/to/projects'
```

This installs or configures the command-line prerequisites, Graphify, Claude memory, GitHub MCP, Playwright MCP, and filesystem MCP. It configures **Claude Code and Codex**. It does not automatically add command-based local MCP servers to Claude Desktop.

After changing MCP registrations, restart Claude Code and Codex or begin a new session so they load the new tool definitions.

## 2. Create the Project

Choose a directory inside the allowed filesystem root. For example:

```powershell
$projectPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Projects/MyProject'
New-Item -ItemType Directory -Path $projectPath
Set-Location $projectPath
git init
```

Create the initial project structure appropriate for the language or framework, then add at least:

```text
MyProject/
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── .gitignore
├── .env.example
├── docs/
│   ├── architecture.md
│   └── decisions/
├── src/
└── tests/
```

Do not create an actual `.env` from a template until the project needs it. When you do, add `.env` to `.gitignore` before adding secrets.

Make the initial commit after the generated scaffold builds and tests successfully:

```powershell
git add .
git commit -m "Initial project scaffold"
```

## 3. Write Shared Project Instructions

Use checked-in files for durable rules. Do not rely on chat history or memory as the only copy of important project decisions.

### `README.md`

Document what the project does, prerequisites, local setup, configuration, and the shortest build/test/run commands.

### `AGENTS.md` for Codex

Codex uses `AGENTS.md` for repository guidance. Keep it operational and verifiable:

```markdown
# Project working agreement

## Commands

- Install: `<command>`
- Build: `<command>`
- Test: `<command>`
- Lint: `<command>`
- Run locally: `<command>`

## Architecture

- Keep domain logic independent from infrastructure.
- Put external integrations behind interfaces.
- Record consequential architecture decisions in `docs/decisions/`.

## Workflow

- Read relevant tests before changing behavior.
- Make the smallest coherent change.
- Run the checks affected by the change.
- Never commit secrets, generated credentials, or local `.env` files.
```

More specific `AGENTS.md` files may be added in subdirectories when one part of the repository needs different rules. See [Codex project guidance](https://learn.chatgpt.com/docs/concepts/customization#agents-guidance).

### `CLAUDE.md` for Claude Code

Use the same concrete commands and constraints, adapting only tool-specific instructions. Claude Code can generate a first draft with `/init`, but review it before committing:

```text
/init
```

Keep architecture rationale in versioned documentation or ADRs. Memory may point to those documents, but it should not become their only home.

## 4. First Run with Claude Code

Open PowerShell at the repository root:

```powershell
Set-Location 'D:\Dropbox\Projects\MyProject'
claude
```

In Claude Code:

1. Run `/init` if `CLAUDE.md` does not exist.
2. Review and edit the generated instructions.
3. Run `/context` to confirm which instructions loaded.
4. Run `/memory` to inspect memory settings.
5. Check the MCP list and confirm `github`, `playwright`, and `filesystem` are connected.
6. Run `/graphify .` when Graphify is available and the repository has enough source code to index.

Claude Code is designed to start from a project directory with `claude`; Anthropic also recommends `claude doctor` when diagnosing the installation. See [Claude Code setup](https://docs.anthropic.com/en/docs/claude-code/getting-started).

Suggested first prompt:

```text
Read CLAUDE.md, README.md, the architecture notes, and the test configuration.
Inspect the repository without editing. Tell me how to build, test, and run it;
summarize the main components; identify missing setup documentation; and propose
the smallest next implementation task.
```

Before accepting changes, ask Claude Code to run the relevant build, test, and lint commands and summarize the diff.

## 5. First Run with Codex

### Codex CLI

Start from the repository root:

```powershell
Set-Location 'D:\Dropbox\Projects\MyProject'
codex
```

### Codex Desktop App

Open the repository folder as the task workspace, then create a new task. Codex should discover the root `AGENTS.md`; nested `AGENTS.md` files apply to their directory trees.

In the new task:

1. Use `/mcp` or `/mcp verbose` to confirm the local MCP tools loaded.
2. Ask Codex to read `AGENTS.md`, `README.md`, and relevant architecture documents.
3. Request a plan or repository orientation before the first substantial edit.
4. Keep live GitHub requests explicit when they are needed: “Use the GitHub MCP server to inspect issue 123.”

Suggested first prompt:

```text
Read AGENTS.md and README.md. Inspect the repository and test setup without
editing. Explain the architecture, exact build/test/run commands, current Git
status, and the smallest useful next task. Flag contradictions or missing
instructions before proposing changes.
```

Codex uses prompt context for one-off instructions, `AGENTS.md` for durable repository guidance, and MCP servers/connectors for live external data. See [Codex MCP customization](https://learn.chatgpt.com/docs/concepts/customization#mcp).

## 6. First Run with Claude Desktop

Claude Desktop is not the same working model as a terminal agent rooted in a repository. Choose one of these approaches.

### Recommended for Local Project Work: Cowork

1. Open Claude Desktop and select Cowork.
2. Create a task and explicitly grant access to `D:\Dropbox\Projects\MyProject`.
3. Ask Claude to read `README.md`, `CLAUDE.md`, and the architecture notes first.
4. Review the folder access shown by Claude before allowing edits.

Cowork limits file access to folders you connect. See [Install Claude Desktop and use Cowork](https://support.claude.com/en/articles/10065433-install-claude-desktop).

### Normal Desktop Chat

For discussion and document review, create a Claude Project and add the relevant project documents, or attach files directly to a conversation. Treat uploaded files as snapshots: they do not automatically track later repository changes.

For live services such as GitHub, use Claude’s account connector from **Customize → Connectors**. Connectors can be enabled for an individual conversation from the `+` menu. See [Claude connectors](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claudes-capabilities).

For local tools, use a reviewed Desktop Extension from **Settings → Extensions**. Connected extensions and their tools can be inspected from the `+` button under **Connectors**. See [local MCP servers in Claude Desktop](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop).

The Docker Compose GitHub MCP server installed by this workspace is registered with Claude Code and Codex. It is not automatically exposed to Claude Desktop. For Desktop, prefer the managed GitHub connector unless you deliberately package the local server as a Desktop Extension or expose a secured remote MCP endpoint.

Suggested first prompt for Cowork:

```text
Work only inside the connected MyProject folder. Read README.md, CLAUDE.md,
AGENTS.md, and docs/architecture.md. Do not edit yet. Explain how the project is
built, tested, and run, then identify missing documentation and the safest first
task.
```

## 7. Normal Development Loop

At the beginning of a task:

1. Pull the latest changes and inspect `git status`.
2. Open the repository root in the chosen client.
3. Confirm that `AGENTS.md` or `CLAUDE.md` loaded.
4. Refresh Graphify after material structural changes.
5. Query GitHub only when current issue, PR, or Actions state matters.

During implementation:

1. Verify assumptions in source code and tests.
2. Use memory for conventions and prior lessons, not as proof of current behavior.
3. Use Playwright only for relevant browser behavior.
4. Review external write operations before allowing them.

Before finishing:

```powershell
git status
git diff --check
```

Then run the project’s build, test, and lint commands; review the complete diff; update documentation or ADRs; and commit only intentional files.

## 8. Quick Troubleshooting

- **Instructions did not load:** confirm the client was opened at the repository root and that the filename is exactly `AGENTS.md` or `CLAUDE.md`.
- **MCP server missing:** restart the client or start a new session, then inspect `/mcp` in Codex or the MCP list in Claude Code.
- **GitHub MCP fails:** confirm Docker Desktop or Docker Engine is running and `GITHUB_PERSONAL_ACCESS_TOKEN` is set in `setup/docker/.env`.
- **GitHub access denied:** verify the token’s repository access and scopes. Read-only mode cannot add permissions the token does not possess.
- **Filesystem MCP cannot reach the project:** confirm the project is under the configured allowed root, currently `D:\Dropbox`.
- **Claude Desktop cannot see local MCP tools:** install an appropriate Desktop Extension; Claude Code registrations do not automatically become Desktop registrations.
- **Graph information is stale:** rerun `/graphify .` after moving files, changing module boundaries, or performing a substantial refactor.
- **A secret appears in Git:** stop before pushing, remove it from tracked files and history as appropriate, rotate it, and confirm `.gitignore` is correct.
