---
title: Workspace blueprint
sidebar_position: 1
description: Architecture and staged rollout for a persistent, cross-tool AI coding workspace.
---

# Ben’s AI Coding Workspace Blueprint

> A practical, staged design for giving coding agents a structural map of the code, durable project knowledge, and controlled access to live systems—without confusing any one of those capabilities with “memory.”

**Status checked:** 22 July 2026  
**Supported workstation environments:** Windows, macOS, and Ubuntu/Debian with PowerShell, VS Code, Claude Code, Codex, and multiple repositories

---

## Executive summary

Ben’s concept is a persistent, cross-tool workspace in which an AI assistant can quickly recover:

1. **What the code is and how it connects** — a structural code graph.
2. **Why the project works this way** — durable instructions, decisions, and learned conventions.
3. **What is happening now** — current repository, pull-request, issue, database, and browser state.
4. **What the agent is allowed to do** — narrowly scoped tools, credentials, and write permissions.

These are complementary capabilities, not substitutes:

| Layer | Best source | Answers | Typical freshness |
|---|---|---|---|
| Source of truth | Git repository, specs, ADRs | “What is actually committed?” | Current at checkout |
| Structural map | Graphify | “What calls, imports, implements, or depends on this?” | Current at last scan |
| Durable context | `CLAUDE.md`, Claude Code auto-memory; optionally claude-mem | “What conventions, decisions, and lessons should persist?” | Curated or learned |
| Live tools | GitHub, database, filesystem, Playwright MCP integrations | “What is the live state, and can I act on it?” | Query-time |

The recommended starting stack is intentionally small:

- **Graphify** for repository structure.
- **Claude Code’s built-in `CLAUDE.md` and auto-memory** for instructions and learned project context.
- **GitHub’s official MCP server** for live repository work.
- **Playwright MCP** only for projects that need browser inspection or UI testing.
- The coding agent’s **native filesystem and terminal tools** unless a separate filesystem MCP server is genuinely needed.
- Direct database tooling first; add a database MCP server only after selecting and security-reviewing a maintained implementation.

Do **not** begin with Neo4j, a custom nightly indexer, Brainspike, and several overlapping memory products. First measure where context and navigation time are actually being spent.

---

## The idea: a persistent project brain, not a larger prompt

The objective is not to pour every available fact into every conversation. That would increase context usage and make instructions harder to follow. The objective is to retrieve the smallest trustworthy slice needed for the current task.

```text
                         ┌──────────────────────────┐
                         │  Specs, code, ADRs, Git  │
                         │     source of truth       │
                         └────────────┬─────────────┘
                                      │
                 ┌────────────────────┼────────────────────┐
                 │                    │                    │
                 ▼                    ▼                    ▼
       ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
       │ Graphify index   │  │ Durable context  │  │ Live MCP tools   │
       │ symbols + edges  │  │ rules + lessons  │  │ GitHub/browser/  │
       │ architecture map │  │ decisions + prefs│  │ approved systems │
       └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
                └─────────────────────┼─────────────────────┘
                                      ▼
                         ┌──────────────────────────┐
                         │ Claude Code / Codex /    │
                         │ Copilot / other agents   │
                         └──────────────────────────┘
```

### What belongs where

- Put **non-negotiable commands and conventions** in a checked-in instruction file such as `CLAUDE.md` (and the equivalent supported by other agents).
- Put **architectural decisions and their rationale** in ADRs or project documentation. Memory may point to them; it should not become their only home.
- Let **auto-memory** retain discovered build quirks, debugging lessons, and personal workflow preferences.
- Let **Graphify** derive structural relationships from the repository rather than manually restating them in memory.
- Use **MCP tools** to fetch live state or perform bounded actions. MCP is a tool protocol, not inherently a memory system.

---

## Graphify: the structural map

Graphify is currently presented by its publisher as a free, MIT-licensed command-line tool that parses a repository locally and produces a knowledge graph. Its current documentation says it supports 36 languages and registers a `/graphify` skill with 17 coding assistants, including Claude Code, Codex, Cursor, GitHub Copilot, and Gemini CLI.

Its value is strongest for questions such as:

- What calls this method or service?
- Which implementations satisfy this interface?
- What depends on this namespace or module?
- Where does a request travel across layers?
- What are the major clusters in an unfamiliar repository?

It is less valuable for a tiny repository, a single-file edit, new code with little existing structure, or questions that require runtime rather than static relationships.

### Verified installation on Windows

Graphify’s current quickstart recommends `uv`, with `pipx` and `pip` as alternatives. If `uv` is already installed:

```powershell
uv tool install graphifyy
graphify install
```

The package name is `graphifyy` (two `y`s); the installed command is `graphify`.

Then, from a supported coding assistant opened at the repository root:

```text
/graphify .
```

Current documented outputs are:

```text
graphify-out/
├── graph.html
├── graph.json
└── GRAPH_REPORT.md
```

For subsequent scans:

```text
/graphify . --update
```

For deeper analysis:

```text
/graphify . --mode deep
```

Before committing, decide whether `graphify-out/` is a shared artifact or a local generated artifact. If local, add it to `.gitignore`. Review generated reports before trusting them; parsing and inferred relationships can be incomplete, especially around reflection, dependency injection, generated code, and runtime configuration.

### What the token-reduction claim really means

Graphify can reduce context for structural navigation when an agent queries a compact graph instead of repeatedly reading many files. That mechanism is credible. A headline such as “70% reduction” is **not a guaranteed workspace-wide result**, however. Savings depend on repository size, language support, question type, index freshness, and whether the agent actually uses the graph.

As of this review, the readily available large reduction claims come from the product’s own materials rather than a broadly replicated, independent benchmark. Treat the claim as a hypothesis to measure, not a purchasing or architecture assumption.

Track these values on a few representative tasks:

- Time until the first correct architectural answer.
- Number of source files opened.
- Input/context tokens, when the client exposes them.
- Correctness and completeness of dependency/call-path answers.
- Time spent updating or troubleshooting the graph.

**Authoritative references:** [Graphify quickstart](https://graphify.com/docs), [How Graphify works](https://graphify.com/concepts), [What is Graphify?](https://graphify.com/what-is-graphify)

---

## Memory: decisions and learning, not a substitute for the code graph

### Recommended default: Claude Code’s built-in memory

Claude Code now officially provides two persistent mechanisms:

- `CLAUDE.md`: instructions written and maintained by people.
- Auto-memory: notes Claude accumulates from work, corrections, preferences, build commands, and debugging discoveries.

Auto-memory is enabled by default in current Claude Code releases. The official documentation says it requires Claude Code 2.1.59 or later.

Check the version:

```powershell
claude --version
```

Inside Claude Code, inspect and manage all memory locations with:

```text
/memory
```

Run `/context` to verify what was actually loaded. Claude Code stores repository memory locally under its project memory directory and loads only the beginning of the memory index at session start; detail files can be read when relevant. This is useful progressive disclosure without a third-party daemon.

Start a project instruction file with:

```text
/init
```

Then edit the generated `CLAUDE.md` so it contains durable, high-value facts rather than a copy of information the agent can derive from the repository. Good entries include:

```markdown
# Project working agreement

## Build and test
- Restore: `dotnet restore`
- Build: `dotnet build --no-restore`
- Test: `dotnet test --no-build`

## Architecture constraints
- Domain projects must not depend on infrastructure projects.
- New request validation uses FluentValidation.

## Workflow
- Read the relevant spec and ADR before changing a public contract.
- Add or update tests with behavioral changes.
- Never commit secrets or local `.env` files.
```

Keep rationales and durable decisions in ADRs, for example `docs/adr/0007-message-bus-selection.md`, and let `CLAUDE.md` point to them.

**Authoritative reference:** [Claude Code: How Claude remembers your project](https://code.claude.com/docs/en/memory)

### Optional: claude-mem

`claude-mem` is an active third-party project, not an Anthropic product. It captures coding-session activity, compresses it, stores searchable observations, and can inject relevant context into later sessions. Its documentation currently describes support for Claude Code and other agents, plus a Claude Desktop skill for searching the stored memory.

Use it only if the built-in memory fails a concrete requirement, such as richer session-history search, a web viewer, or sharing/querying memories across several supported agents.

Current documented Claude Code installation options are:

```powershell
npx claude-mem install
```

or, inside Claude Code:

```text
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem
```

Restart Claude Code afterward. Do **not** use `npm install -g claude-mem` for plugin setup; the project explicitly says that installs only its SDK/library and does not configure hooks or the worker service.

Before enabling it on private repositories, review:

- What session content and prompts it captures.
- Where its local database and logs live.
- Whether any cloud synchronization is enabled.
- How secrets and sensitive output are excluded.
- Memory isolation between repositories with similar names.
- The ongoing context cost of automatic injection.

Run a two-week built-in-memory trial before installing it. Two memory systems that independently inject context can duplicate facts, increase token use, and disagree.

**Authoritative references:** [claude-mem repository and current quickstart](https://github.com/thedotmack/claude-mem), [claude-mem documentation](https://docs.claude-mem.ai/)

### Claude Desktop: important distinction

Claude Desktop and Claude Code are different hosts. A Claude Code plugin or hook is not automatically a Claude Desktop extension.

For Claude Desktop, Anthropic’s current supported route is:

1. Open **Settings → Extensions**.
2. Select **Browse extensions** and install an Anthropic-reviewed extension; or
3. Open **Advanced settings → Install Extension…** to install a trusted `.mcpb` package.
4. Check the chat composer’s **Connectors** menu or Developer settings to confirm the tools are connected.

claude-mem currently advertises a Claude Desktop search skill, but it remains a third-party layer. Verify its exact Desktop setup in its current documentation before enabling it; do not assume the Claude Code plugin commands install it into Desktop.

**Authoritative reference:** [Anthropic: Getting started with local MCP servers on Claude Desktop](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)

### Brainspike status

Brainspike should be treated as experimental. The discoverable material is principally a community project/post rather than mature vendor documentation. Automatic prompt injection also carries a direct context-cost and trust tradeoff. It is not part of the recommended rollout until it has a stable release process, clear storage/privacy documentation, and a measurable advantage over built-in memory or claude-mem.

---

## MCP tools: live capabilities

MCP lets an assistant discover and invoke tools or resources. It does not automatically make the assistant remember previous work. Memory only exists if a particular MCP server deliberately stores and retrieves it.

### 1. GitHub MCP server — install early

GitHub maintains an official MCP server for repositories, issues, pull requests, Actions, and related workflows. Prefer the remote server with OAuth when the chosen client supports it. Otherwise use the official local container or binary and a least-privilege token.

For GitHub Copilot in supported IDEs, follow GitHub’s current one-click or remote-server flow. For another MCP host, use the host-specific guide linked from the official repository rather than copying one client’s JSON into another.

Security defaults:

- Start in **read-only mode** where supported.
- Enable only required toolsets, such as repositories, issues, and pull requests.
- Use a fine-grained, short-lived token when OAuth is unavailable.
- Never put the token in a committed configuration file.
- Require confirmation for pushes, merges, issue edits, and workflow dispatches.

**Authoritative reference:** [GitHub’s official MCP server](https://github.com/github/github-mcp-server)

### 2. Filesystem MCP — usually redundant for coding agents

Claude Code, Codex, and IDE coding agents already have scoped filesystem access. Adding another filesystem MCP server may duplicate tools and expand the attack surface.

Install it only when a host lacks native file access or when a deliberately separate, narrowly scoped root is useful. The maintained MCP reference server is published as `@modelcontextprotocol/server-filesystem` and requires explicit allowed directories (or an MCP client that correctly supplies Roots).

Never grant a filesystem tool an entire drive or user profile. Grant only the repositories or documentation folders needed for the current workflow.

**Authoritative references:** [MCP Filesystem reference server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem), [MCP example servers and maintenance status](https://modelcontextprotocol.io/examples)

### 3. Database tools — select deliberately

The earlier blanket recommendation to “install PostgreSQL / SQLite MCP” is too vague. The MCP project’s example catalog distinguishes maintained reference servers from archived examples, and an archived demonstration is not automatically a suitable production tool.

For development databases, begin with the database CLI or the coding agent’s existing terminal tools. If an MCP server adds meaningful schema discovery or safe query workflows, select a currently maintained implementation for the exact database and review it first.

Minimum controls:

- Use a read-only database role by default.
- Connect to local/dev or a sanitized replica, not production.
- Restrict schemas and network reachability.
- Set statement timeouts and row limits.
- Keep credentials in the operating system’s secret store or the host’s encrypted extension settings.
- Require separate, explicit authorization for migrations and writes.

### 4. Playwright MCP — add when UI work justifies it

Microsoft’s Playwright MCP server gives an agent structured browser automation for navigation, inspection, form interaction, and UI testing.

Current Codex CLI setup documented by Microsoft:

```powershell
codex mcp add playwright npx "@playwright/mcp@latest"
```

For VS Code, the official repository provides one-click installation and this CLI form:

```powershell
code --add-mcp '{"name":"playwright","command":"npx","args":["@playwright/mcp@latest"]}'
```

Shell quoting can vary on Windows; use the repository’s one-click installer if the command is rejected. For Claude Desktop, first check its reviewed Extensions directory; otherwise install only a trusted desktop-extension package or follow the current host-specific configuration guidance.

Use isolated browser profiles for test automation. Do not expose an everyday signed-in browser profile unless the task truly requires it and the consequences are understood.

**Authoritative reference:** [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp)

---

## Recommended stack for Ben

### Core stack

| Component | Recommendation | Why |
|---|---|---|
| Repository truth | Git + specs + ADRs | Auditable, portable, human-readable |
| Project instructions | `CLAUDE.md` and equivalent agent instruction files | Stable commands, constraints, conventions |
| Learned memory | Claude Code auto-memory | Built in, local, inspectable, minimal setup |
| Structural index | Graphify | Fast architecture and dependency navigation |
| Remote workflow | Official GitHub MCP server | Live PR, issue, repository, and Actions context |
| Browser work | Playwright MCP, only where needed | Repeatable UI inspection and testing |
| Local files | Native coding-agent tools | Fewer redundant tools and permissions |
| Database | Native CLI first; reviewed MCP later | Safer and easier to constrain |

### Optional after measurement

- **claude-mem:** if searchable cross-session history materially outperforms built-in auto-memory.
- **Cross-agent instruction generation:** a small script or canonical policy source that produces the appropriate Claude, Codex, and Copilot instruction files without copying stale prose by hand.
- **Central architecture catalog:** if dozens of repositories need an inventory of owners, services, environments, and links.
- **Neo4j-backed cross-repository graph:** only when cross-repo relationship queries justify operating a graph database and custom ingestion pipeline.

### Not recommended initially

- Multiple automatic memory injectors at once.
- A custom Graphify clone.
- A nightly indexer before update-on-demand proves insufficient.
- Broad filesystem access.
- Production database write tools.
- Enabling every GitHub or MCP toolset “just in case.”
- Treating generated summaries as authoritative over code, tests, specs, or ADRs.

---

## Day-to-day workflow

### Starting or returning to a repository

1. Pull the latest changes and check the worktree state.
2. Open the repository at its root.
3. Confirm that project instructions are loaded.
4. Update the Graphify graph if the repository changed materially.
5. Ask the agent for a short task-oriented orientation, not a complete repository summary.
6. Query GitHub only when live issue, PR, or Actions state is relevant.

Example prompt:

```text
Read the project instructions and the linked spec. Use the code graph to identify
the request path and likely change surface. Check GitHub only for the referenced
issue and open PRs. Give me the proposed files, tests, risks, and unresolved
questions before editing.
```

### During implementation

1. Use the graph for exploration and change-impact hypotheses.
2. Verify important claims in source code and tests.
3. Use memory for conventions and prior lessons, not as proof of current behavior.
4. Use Playwright only for relevant UI behavior.
5. Ask before any consequential external write.

### Finishing a task

1. Run proportional build, test, and lint checks.
2. Update specs or ADRs when the contract or rationale changed.
3. Keep only durable lessons in memory; do not store transient task status forever.
4. Refresh the graph if structural changes were substantial.
5. Use GitHub tooling for the PR only after reviewing the diff and permissions.

---

## Staged rollout

### Stage 0 — baseline (one week)

- Select two medium-sized representative repositories.
- Record navigation time, files opened, approximate context/token use, and answer quality for 10 recurring tasks.
- Inventory existing agent instruction and memory files.
- Remove secrets and obsolete instructions before connecting new tools.

**Exit criterion:** a usable baseline and a list of the three most common context failures.

### Stage 1 — native memory hygiene (week two)

- Upgrade Claude Code to a version that supports auto-memory.
- Create or trim `CLAUDE.md` with `/init` and manual review.
- Put decision rationale in ADRs.
- Inspect `/memory` and `/context` regularly.
- Do not install a third-party memory layer yet.

**Exit criterion:** repeated corrections decline, and important instructions are reliably loaded.

### Stage 2 — Graphify pilot (weeks two to three)

- Install Graphify on one representative .NET repository and one mixed-language repository.
- Build the initial graph and run the same baseline architecture questions.
- Test incremental updates after refactors.
- Document unsupported or incorrectly inferred relationships.

**Exit criterion:** clear improvement in either navigation time or context use without unacceptable staleness or errors.

### Stage 3 — live GitHub integration (week three)

- Enable the official GitHub MCP server with read-only, minimal toolsets.
- Validate repository, issue, PR, and Actions reads.
- Enable selected write operations only after the read workflow is stable.

**Exit criterion:** the agent can retrieve live project state without broad credentials or unnecessary tools.

### Stage 4 — task-specific capabilities (weeks four to six)

- Add Playwright MCP to frontend repositories that need it.
- Add a reviewed, read-only database integration only where native tools are inadequate.
- Pilot claude-mem only if built-in memory has a documented gap.

**Exit criterion:** each added component solves a measured problem and has a named owner, update path, and uninstall path.

### Stage 5 — cross-repository intelligence (later)

Build a central catalog or graph only if repeated questions cross repository boundaries, for example:

- Which services publish or consume this event?
- Which applications depend on this shared package?
- Which deployment, owner, issue, and ADR belong to this service?

At that point, ingest repository structure, ADR links, service metadata, and selected GitHub state into a governed cross-repository model. Keep the repositories and live systems as the sources of truth.

---

## Security and maintenance rules

Persistent context and tool access amplify both good information and malicious instructions. Treat repository text, issues, pull requests, web pages, tool output, and retrieved memories as untrusted data—not authority.

- Keep secrets out of prompts, graphs, reports, memory files, and Git.
- Inspect generated configuration before running it.
- Prefer reviewed extensions and official repositories.
- Pin or periodically review third-party package versions rather than silently trusting “latest” forever.
- Restrict files, repositories, toolsets, database roles, and browser profiles.
- Separate read and write capabilities.
- Review memories for stale or cross-project facts.
- Rebuild or update structural indexes after material changes.
- Maintain a short inventory containing component, version, data location, permissions, update command, and uninstall procedure.

---

## Success measures

Review the pilot after 30 days:

| Measure | Desired direction |
|---|---|
| Time to regain project orientation | Down |
| Files read before a correct architecture answer | Down |
| Repeated corrections about conventions | Down |
| Context/input tokens for matched tasks | Down |
| Incorrect claims caused by stale memory | Near zero |
| Incorrect structural relationships | Documented and declining |
| Tool permission prompts that feel surprising | Zero |
| Maintenance time for the workspace | Low and predictable |

Adopt a component only if its measured benefit exceeds its context, security, and maintenance cost.

---

## Final recommendation

Build the workspace from the inside out:

1. Make repository instructions, specs, and ADRs trustworthy.
2. Use Claude Code’s built-in auto-memory before adding another memory engine.
3. Pilot Graphify for structural navigation and measure it against a baseline.
4. Connect the official GitHub MCP server with minimal permissions.
5. Add Playwright and database capabilities only to workflows that require them.
6. Consider claude-mem or a cross-repository knowledge graph only after a specific, measured gap remains.

The resulting system is not one giant memory. It is a disciplined retrieval architecture: **code and documents provide truth, Graphify provides structure, memory preserves useful learning, and MCP provides controlled access to live state.**

---

## Verification notes and source index

The commands and status statements in this document were checked against project or vendor documentation on 22 July 2026:

- [Graphify documentation](https://graphify.com/docs)
- [Graphify concepts](https://graphify.com/concepts)
- [Claude Code memory documentation](https://code.claude.com/docs/en/memory)
- [Anthropic Claude Desktop local MCP/extension guide](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)
- [claude-mem official repository](https://github.com/thedotmack/claude-mem)
- [GitHub’s official MCP server](https://github.com/github/github-mcp-server)
- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp)
- [MCP example servers and maintenance status](https://modelcontextprotocol.io/examples)
- [MCP Filesystem reference server](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)

Because these projects evolve quickly, re-check the linked quickstarts before installing or upgrading.
