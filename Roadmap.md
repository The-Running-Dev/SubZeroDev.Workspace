# Roadmap

A prioritized backlog for the LLM Workspace Toolkit, produced from a full read of
`setup-llm/`, `.github/`, `Dockerfile`, `container-entrypoint.ps1`, and `setup-llm/docs/`.

Each item states the evidence, why it matters, and a proposed fix. Items are
grouped by priority, not by area. Sizes are rough: **S** under an hour, **M** a
half day, **L** a day or more.

**How this was assessed:** every PowerShell script and workflow was read; relative
links in `README.md` and `setup-llm/docs/**` were resolved (all valid); and the two
correctness bugs formerly in P0 (now moved, see below) were reproduced by executing the module directly under
`pwsh 7.6.3`, not inferred from reading.

---

## What already works well

Worth stating plainly, because the backlog below is all problems:

- **The security posture is genuinely thought through.** Filesystem MCP is off by
  default and refuses to grant a filesystem root
  (`setup-llm/scripts/workstation/install-filesystem-mcp.ps1:20`). GitHub MCP defaults to
  `GITHUB_READ_ONLY=1` with an explicit toolset allow-list. No generic database MCP
  is installed. The compose file fails fast on a missing token via `${VAR:?}`.
- **Platform dispatch is clean.** `setup.ps1` is 31 lines that detect the OS and
  forward `$PSBoundParameters` — the per-platform scripts stay small and readable.
- **`-WhatIf` is honored throughout**, including the awkward cases where a preview
  cannot inspect a tool it deliberately declined to install
  (`setup-llm/scripts/workstation/install-graphify.ps1:15-20`).
- **The documentation is unusually good** for a tooling repo, and the single-source
  README → Docusaurus pipeline (`setup-llm/scripts/setup-docs.ps1`) avoids the usual drift.
- **The workspace blueprint is honest** — it explicitly argues *against* starting
  with Neo4j, custom indexers, and overlapping memory products, and stages the
  rollout behind measurement.

---

## Moved to SubZeroDev.GitHub

Project creation moved to [SubZeroDev.GitHub](https://github.com/The-Running-Dev/SubZeroDev.GitHub) (`scripts/New-Project.ps1`), and the items about it moved with it. The numbers are kept here so the gaps below are explained.

- **1. Build and test validation always reports success.** Fixed in the move: the exit code is now checked ([SubZeroDev.GitHub#2](https://github.com/The-Running-Dev/SubZeroDev.GitHub/pull/2)).
- **2. `-AutoCommit` commits regardless of validation outcome.** `New-Project.ps1` always commits and reports a failed build or test as a warning; its README says so ([SubZeroDev.GitHub#2](https://github.com/The-Running-Dev/SubZeroDev.GitHub/pull/2)).
- **3. Generated Node.js starter does not build.** [SubZeroDev.GitHub#3](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/3).
- **4. Python starter targets a deprecated toolchain.** [SubZeroDev.GitHub#4](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/4).
- **6. No end-to-end scaffold test.** [SubZeroDev.GitHub#5](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/5).
- **9. `Invoke-Expression` on command strings.** [SubZeroDev.GitHub#6](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/6).
- **12. `-Client` accepts different values in different scripts.** Fixed in the move: `New-Project.ps1` takes `Both`, `ClaudeCode` or `Codex`, like the workstation scripts.
- **14. Four of six advertised languages have no starter.** [SubZeroDev.GitHub#7](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/7).
- **23. Make the Graphify integration first-class.** Every part of it is about new projects: [SubZeroDev.GitHub#8](https://github.com/The-Running-Dev/SubZeroDev.GitHub/issues/8).

---

## P1 — The testing and CI gap

### 5. No CI runs against the PowerShell scripts at all (M)

`.github/workflows/docs-pages.yml` is the only workflow, and its `paths:` filter
(`:7-18`, `:22-33`) covers `setup-llm/docs/**`, `setup-llm/scripts/setup-docs.ps1`,
`setup-llm/README.md`, the Dockerfile and the submodule — but **not** `setup-llm/scripts/setup.ps1`,
`setup-llm/setup-*.ps1`, `setup-llm/modules/**`, or `setup-llm/scripts/**`.

So the provisioning logic that is the actual product of this repo has zero
automated verification. It also means the published container silently goes stale: the
`container` job copies `setup-llm/` into the image, but a change to a setup script does
not match the path filter and therefore never triggers a rebuild.

**Fix, in order:**

1. Add `setup-llm/**` (excluding `setup-llm/docs/**`) to the container job's trigger paths,
   or split the container into its own workflow with correct paths.
2. Add a `scripts-ci.yml` workflow running **PSScriptAnalyzer** across `setup-llm/`.
   This is near-zero effort and would have caught several items below.
3. Add **Pester** tests for the pure logic — `Test-DotEnvValueSet` and
   `Convert-ReadmeLinks`. These need no network and no installs.
4. Add a matrix smoke job (ubuntu + windows + macos) that runs
   `./setup-llm/scripts/setup.ps1 -Client Both -WhatIf` and asserts a clean exit.

### 7. No test for the docs sync (S)

`setup-llm/scripts/setup-docs.ps1` does destructive regex rewriting of the README
(`Convert-ReadmeLinks`, `:66-83`) and deletes the template `docs/` tree
(`:47`). It is entirely untested. `Convert-ReadmeLinks` also reads
`$repositoryUrl` from the caller's scope rather than taking it as a parameter
(`:74-75`, assigned at `:86`) — it happens to work because of call ordering, but
under `Set-StrictMode -Version Latest` any reordering turns it into a runtime
error.

**Fix:** pass `$repositoryUrl` as a parameter, and add Pester cases for the link
rewrite rules (relative doc link, `setup-llm/` tree link, `.md` suffix stripping).

---

## P2 — Supply chain and hardening

### 8. Every installed dependency floats to latest (M)

Nothing in the setup path is version-pinned:

| Component | Location | Current |
|---|---|---|
| GitHub MCP server | `setup-llm/docker/docker-compose.yml:3` | `:latest` |
| claude-mem | `setup-llm/scripts/workstation/install-claude-mem.ps1:18` | `@latest` |
| Playwright MCP | `setup-llm/scripts/workstation/install-playwright-mcp.ps1:13` | `@latest` |
| Filesystem MCP | `setup-llm/scripts/workstation/install-filesystem-mcp.ps1:28` | `npx -y`, unversioned |
| Codex CLI / Claude Code | `setup-llm/scripts/setup-macos.ps1:43-44`, `setup-llm/scripts/setup-ubuntu.ps1:85-86` | unversioned npm global |
| Codex CLI / Claude Code | `setup-llm/scripts/setup-windows.ps1:31-32` | unversioned Winget package |
| graphifyy | `setup-llm/scripts/workstation/install-graphify.ps1:30` | unversioned `uv tool install` |

A repo whose documentation argues for least-privilege tokens and deliberate
security review of database servers should not silently execute whatever those
six publishers pushed most recently. This is also why setup is not reproducible:
two runs a week apart give different workstations.

**Fix:** introduce a single `setup-llm/config/versions.psd1` with pinned versions
(digest for the container image, exact versions for npm packages), consumed by all
installers. Add a documented `-AllowLatest` switch for people who want the current
behavior, and a renovate/dependabot config to bump the pins via PR.

### 10. The `act` installer pipes a downloaded script to sudo without verification (S)

`setup-llm/scripts/setup-ubuntu.ps1:60-75` downloads `install.sh` from `master` on GitHub and
executes it with elevated privileges, with no checksum or signature check. Windows
and macOS install `act` from Winget and Homebrew respectively, so Linux is the only
platform taking this path.

**Fix:** prefer the apt/`gh extension` route, or download a pinned release tarball
and verify its published checksum before executing.

### 11. GitHub MCP container is unhardened (S)

`setup-llm/docker/docker-compose.yml` runs the MCP server — which holds a GitHub PAT in
its environment — with no `read_only`, `cap_drop`, `security_opt`, `pids_limit`, or
memory limit, and on the default bridge network.

**Fix:** add `read_only: true`, `cap_drop: [ALL]`,
`security_opt: [no-new-privileges:true]`, and modest resource limits. Also consider
moving the token to a Docker secret or `env_file` scoped to the service rather than
a plain environment variable.

---

## P3 — Consistency and developer experience

### 13. `setup-llm/config/` is dead code (S)

`setup-llm/config/setup-config.example.yaml` and `setup-llm/config/setup-schema.json` describe
a declarative configuration system — validation checks, troubleshooting
entries, MCP components. Nothing reads either file. The only
reference anywhere is a file listing in
`setup-llm/docs/architecture/setup-flowcharts.md:368-369`.

This is a fork in the road, not a cleanup:

- **Implement it** — have `setup.ps1` load the YAML so the component list becomes
  data rather than a hardcoded list.
- **Delete it** — if the declarative direction is abandoned, remove both files so
  they stop implying a capability that does not exist.

Pick one. Leaving it as-is is the worst option.

### 15. Missing repository hygiene files (S)

The repo has no `.gitignore`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`,
`CODEOWNERS`, or `.editorconfig`. Consequences:

- `graphify-out/` (and any other local build output) shows up as untracked noise.
- A repo that ships security-sensitive provisioning has no disclosure policy.

**Fix:** add all six. The `.gitignore` should at minimum cover `graphify-out/`,
`node_modules/`, `.env`, and `docs-template/artifacts/`.

### 16. The toolkit does not use its own conventions (S)

Project creation (now in SubZeroDev.GitHub) generates `CLAUDE.md` and `AGENTS.md` for every new project, and
the blueprint argues that non-negotiable commands and conventions belong in a
checked-in instruction file. This repository has neither. Its
`.github/copilot-instructions.md` contains only an empty claude-mem placeholder.

**Fix:** add a root `CLAUDE.md` / `AGENTS.md` covering the PowerShell style rules
already followed (`Set-StrictMode -Version Latest`, `SupportsShouldProcess`,
`Invoke-NativeCommand` for native calls), how to run the docs pipeline, and the
submodule workflow. Dogfooding is the point of the repo.

### 17. Running the docs scripts dirties the working tree (S)

`setup-docs.ps1` writes generated output into the `docs-template` submodule, so
`git status` reports ` m docs-template` after any local docs run. This trains
people to ignore a dirty submodule.

**Fix:** add `ignore = dirty` to the `.gitmodules` entry, or generate into a
gitignored staging directory and point the Docusaurus build at that instead.

### 18. `docs-template/cookies.txt` is a committed credential file (S)

The submodule contains a curl cookie jar holding a JWT refresh token for subject
`admin-001`. It is expired and scoped to `localhost`, so practical risk is low —
but it belongs in the upstream template's `.gitignore`, not in version control.

**Fix:** raise upstream on `The-Running-Dev/Docusaurus-Template`, remove the file,
and add `cookies.txt` to that repo's `.gitignore`.

---

## P4 — Things worth adding

### 19. A `verify` / doctor command (M)

There is no way to answer "is my workstation actually set up correctly?" other than
rerunning setup. A `setup-llm/verify.ps1` that checks each component — CLI present and
on PATH, MCP server registered in each client, GitHub token valid and read-only,
Docker engine reachable, Graphify installed — and prints a pass/fail table would be
the single highest-value addition for day-to-day use.

It also gives CI something meaningful to assert after a container `setup` run.

### 20. An uninstall / rollback path (M)

The blueprint's own Stage 4 exit criterion requires that each added component have
"a named owner, update path, and **uninstall path**"
(`setup-llm/docs/architecture/workspace-blueprint.md`). No uninstall exists. Backing out
of claude-mem, Playwright MCP, or a database registration is currently a manual
`claude mcp remove` / `npm uninstall -g` exercise the user has to reconstruct.

**Fix:** `setup-llm/uninstall.ps1 -Component claude-mem,playwright` with the same
`-WhatIf` support as install.

### 21. Idempotency and re-run guarantees (S)

Most installers check `Test-CommandAvailable` and skip, but
`setup-llm/scripts/workstation/install-github-mcp.ps1` deliberately removes and
re-adds the registration each run (`:105-108`, `:115-118`), and
`setup-llm/scripts/workstation/install-claude-mem.ps1` runs `claude-mem install` and
`start` unconditionally. There is no stated contract for what a second run does.

**Fix:** document the intended behavior per component, and add a `-Force` switch for
the cases where re-registration is the point.

### 22. Structured logging and a transcript (S)

Output is `Write-Host` with ANSI colors. A failed setup on someone else's machine
produces nothing shareable.

**Fix:** wrap runs in `Start-Transcript` to a timestamped file under
`setup-llm/logs/` (gitignored), and mention the log path in the failure message.

### 24. Cross-platform CI for the container (S)

The container is built `linux/amd64` only. `docs-workflow-local.ps1` already notes
that Apple Silicon needs `--platform linux/amd64`. Adding `linux/arm64` to the
buildx platforms would let Apple Silicon and ARM servers run it natively.

---

## Suggested sequencing

1. **Week 1 — stop the bleeding.** Item 15. Small and user-visible. Add
   PSScriptAnalyzer (item 5, step 2) at the same time.
2. **Week 2 — make it testable.** Items 5 (steps 1, 3, 4) and 7. Once CI exists,
   everything after this is safe to change.
3. **Week 3 — supply chain.** Items 8, 10, 11. Pinning is easiest once CI can
   prove the pins still work.
4. **Ongoing.** Decide item 13 (implement or delete `setup-llm/config/`), then build
   items 19 and 20 — the verify and uninstall commands are what turn this from a
   collection of scripts into a maintainable toolkit.
