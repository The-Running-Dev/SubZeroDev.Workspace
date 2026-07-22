# Roadmap

A prioritized backlog for the LLM Workspace Toolkit, produced from a full read of
`setup/`, `.github/`, `Dockerfile`, `container-entrypoint.ps1`, and `setup/docs/`.

Each item states the evidence, why it matters, and a proposed fix. Items are
grouped by priority, not by area. Sizes are rough: **S** under an hour, **M** a
half day, **L** a day or more.

**How this was assessed:** every PowerShell script and workflow was read; relative
links in `README.md` and `setup/docs/**` were resolved (all valid); and the two
correctness bugs in P0 were reproduced by executing the module directly under
`pwsh 7.6.3`, not inferred from reading.

---

## What already works well

Worth stating plainly, because the backlog below is all problems:

- **The security posture is genuinely thought through.** Filesystem MCP is off by
  default and refuses to grant a filesystem root
  (`setup/scripts/workstation/install-filesystem-mcp.ps1:20`). GitHub MCP defaults to
  `GITHUB_READ_ONLY=1` with an explicit toolset allow-list. No generic database MCP
  is installed. The compose file fails fast on a missing token via `${VAR:?}`.
- **Platform dispatch is clean.** `setup.ps1` is 31 lines that detect the OS and
  forward `$PSBoundParameters` — the per-platform scripts stay small and readable.
- **`-WhatIf` is honored throughout**, including the awkward cases where a preview
  cannot inspect a tool it deliberately declined to install
  (`setup/scripts/workstation/install-graphify.ps1:15-20`).
- **The documentation is unusually good** for a tooling repo, and the single-source
  README → Docusaurus pipeline (`setup/setup-docs.ps1`) avoids the usual drift.
- **The workspace blueprint is honest** — it explicitly argues *against* starting
  with Neo4j, custom indexers, and overlapping memory products, and stages the
  rollout behind measurement.

---

## P0 — Correctness bugs

### 1. Build and test validation always reports success (S)

`Test-ProjectBuildable` and `Test-ProjectTestable`
(`setup/modules/ProjectSetup.psm1:767` and `:799`) run the command through
`Invoke-Expression` and `return $true` unless a *PowerShell* exception is thrown.
A native command exiting non-zero does not throw when
`$PSNativeCommandUseErrorActionPreference` is `$false` — which is the default on
this machine (pwsh 7.6.3) and on Windows PowerShell 5.1, the version the script
declares support for.

Reproduced directly:

```
Test-ProjectBuildable -BuildCommand 'sh -c "exit 7"'  →  True
```

So `setup-project.ps1` prints `[OK] Project build succeeded` for a project that
does not build.

**Fix:** capture `$LASTEXITCODE` after invocation and return `$LASTEXITCODE -eq 0`;
or reuse the existing `Invoke-NativeCommand` helper, which already throws on a
non-zero exit. Prefer splitting the command table into `FilePath` + `ArgumentList`
so `Invoke-Expression` can be dropped entirely (see item 9).

### 2. `-AutoCommit` commits regardless of validation outcome (S)

`setup/setup-project.ps1:41-42` documents `-AutoCommit` as "Automatically create initial
commit if validation succeeds", but the implementation at `:330` is an
unconditional `if ($AutoCommit)`. `$buildSuccess` and `$testSuccess` are computed
at `:298-323` and then never read.

Combined with item 1, a broken scaffold is committed and reported as passing.

**Fix:** gate the commit on `$buildSuccess -and $testSuccess` when `-SkipValidation`
was not passed, and add `-CommitEvenIfValidationFails` for the escape hatch — or
change the docstring to match the behavior. Gating is the better default.

### 3. Generated Node.js starter does not build (M)

`setup/scripts/starters/setup-starter-node.ps1` emits a mutually inconsistent
project:

- `build: "tsc"` with `tsconfig.json` `rootDir: ./src` and `include: ["src/**/*"]`,
  but the only source file written is `src/index.js` (`:167`). Without `allowJs`,
  `tsc` compiles nothing.
- `main: "src/index.js"` and `start: "node src/index.js"` run the source, while
  `tsc` outputs to `./dist` — the build output is never used.
- `type: "module"` with `jest@^29`. The generated `jest.config.js` (`:124-133`) is
  correctly ESM (`export default`), but Jest 29's ESM support for the test files
  themselves is experimental and needs `NODE_OPTIONS=--experimental-vm-modules`,
  which the generated `test: "jest"` script does not set.
- `.eslintrc.json` with `eslint@^8` (`:96-117`). Eslintrc is end-of-life; ESLint 9
  uses flat `eslint.config.js`.
- `keywords: ["project", "typescript"]` but no `@typescript-eslint` packages.

**Fix:** pick one language and commit to it. Recommended: TypeScript throughout —
`src/index.ts`, `tsc` build, `start: node dist/index.js`, ESLint 9 flat config,
and either Vitest (ESM-native, no config gymnastics) or Jest with
`--experimental-vm-modules` wired up. Add a smoke test in CI that scaffolds a
project and actually runs `install`/`build`/`test` (see item 4).

### 4. Python starter targets a deprecated toolchain (S)

`setup/scripts/starters/setup-starter-python.ps1` generates `setup.py` alongside
`pyproject.toml`, and the language table in `setup/setup-project.ps1:111` uses
`python setup.py build` — deprecated since setuptools 58 and slated for removal.
Dev dependencies are hard-pinned to mid-2023 (`pytest==7.4.0`, `black==23.7.0`,
`pylint==2.17.5`).

Notably, the workstation setup already installs Astral `uv`
(`setup/scripts/workstation/install-graphify.ps1`), so the toolkit ships a modern
Python toolchain and then scaffolds projects that ignore it.

**Fix:** `pyproject.toml` only, `uv` for dependency management, `ruff` in place of
`black` + `pylint`, and floor constraints (`>=`) rather than frozen `==` pins in a
starter template.

---

## P1 — The testing and CI gap

### 5. No CI runs against the PowerShell scripts at all (M)

`.github/workflows/docs-pages.yml` is the only workflow, and its `paths:` filter
(`:7-18`, `:22-33`) covers `setup/docs/**`, `setup/setup-docs.ps1`,
`setup/README.md`, the Dockerfile and the submodule — but **not** `setup/setup.ps1`,
`setup/setup-*.ps1`, `setup/modules/**`, or `setup/scripts/**`.

So the ~2,400 lines of provisioning and scaffolding logic that are the actual
product of this repo have zero automated verification. This is how items 1–4
survived. It also means the published container silently goes stale: the
`container` job copies `setup/` into the image, but a change to a setup script does
not match the path filter and therefore never triggers a rebuild.

**Fix, in order:**

1. Add `setup/**` (excluding `setup/docs/**`) to the container job's trigger paths,
   or split the container into its own workflow with correct paths.
2. Add a `scripts-ci.yml` workflow running **PSScriptAnalyzer** across `setup/`.
   This is near-zero effort and would have caught several items below.
3. Add **Pester** tests for the pure logic — `Test-DotEnvValueSet`,
   `Convert-ReadmeLinks`, `New-Gitignore`, the language command table, and the two
   validation functions from item 1. These need no network and no installs.
4. Add a matrix smoke job (ubuntu + windows + macos) that runs
   `./setup/setup.ps1 -Client Both -WhatIf` and asserts a clean exit.

### 6. No end-to-end scaffold test (M)

Nothing verifies that `setup-project.ps1` produces a project that builds. A CI job
that scaffolds `node` and `python` into a temp directory and runs the generated
`install`/`build`/`test` commands would directly cover items 3 and 4 and prevent
regressions.

### 7. No test for the docs sync (S)

`setup/setup-docs.ps1` does destructive regex rewriting of the README
(`Convert-ReadmeLinks`, `:66-83`) and deletes the template `docs/` tree
(`:47`). It is entirely untested. `Convert-ReadmeLinks` also reads
`$repositoryUrl` from the caller's scope rather than taking it as a parameter
(`:74-75`, assigned at `:86`) — it happens to work because of call ordering, but
under `Set-StrictMode -Version Latest` any reordering turns it into a runtime
error.

**Fix:** pass `$repositoryUrl` as a parameter, and add Pester cases for the link
rewrite rules (relative doc link, `setup/` tree link, `.md` suffix stripping).

---

## P2 — Supply chain and hardening

### 8. Every installed dependency floats to latest (M)

Nothing in the setup path is version-pinned:

| Component | Location | Current |
|---|---|---|
| GitHub MCP server | `setup/docker/docker-compose.yml:3` | `:latest` |
| claude-mem | `setup/scripts/workstation/install-claude-mem.ps1:18` | `@latest` |
| Playwright MCP | `setup/scripts/workstation/install-playwright-mcp.ps1:13` | `@latest` |
| Filesystem MCP | `setup/scripts/workstation/install-filesystem-mcp.ps1:28` | `npx -y`, unversioned |
| Codex CLI / Claude Code | `setup/setup-macos.ps1:43-44`, `setup/setup-ubuntu.ps1:85-86` | unversioned npm global |
| Codex CLI / Claude Code | `setup/setup-windows.ps1:31-32` | unversioned Winget package |
| graphifyy | `setup/scripts/workstation/install-graphify.ps1:30` | unversioned `uv tool install` |

A repo whose documentation argues for least-privilege tokens and deliberate
security review of database servers should not silently execute whatever those
six publishers pushed most recently. This is also why setup is not reproducible:
two runs a week apart give different workstations.

**Fix:** introduce a single `setup/config/versions.psd1` with pinned versions
(digest for the container image, exact versions for npm packages), consumed by all
installers. Add a documented `-AllowLatest` switch for people who want the current
behavior, and a renovate/dependabot config to bump the pins via PR.

### 9. `Invoke-Expression` on command strings (S)

`setup/modules/ProjectSetup.psm1:787` and `:819` execute build/test commands via
`Invoke-Expression`. The strings come from a fixed table in `setup-project.ps1`, so
this is not currently exploitable — but it is the reason exit codes are lost
(item 1), and it makes any future user-supplied command a shell-injection vector.

**Fix:** model commands as `@{ FilePath = 'npm'; ArgumentList = @('run','build') }`
and route through the existing `Invoke-NativeCommand`.

### 10. The `act` installer pipes a downloaded script to sudo without verification (S)

`setup/setup-ubuntu.ps1:60-75` downloads `install.sh` from `master` on GitHub and
executes it with elevated privileges, with no checksum or signature check. Windows
and macOS install `act` from Winget and Homebrew respectively, so Linux is the only
platform taking this path.

**Fix:** prefer the apt/`gh extension` route, or download a pinned release tarball
and verify its published checksum before executing.

### 11. GitHub MCP container is unhardened (S)

`setup/docker/docker-compose.yml` runs the MCP server — which holds a GitHub PAT in
its environment — with no `read_only`, `cap_drop`, `security_opt`, `pids_limit`, or
memory limit, and on the default bridge network.

**Fix:** add `read_only: true`, `cap_drop: [ALL]`,
`security_opt: [no-new-privileges:true]`, and modest resource limits. Also consider
moving the token to a Docker secret or `env_file` scoped to the service rather than
a plain environment variable.

---

## P3 — Consistency and developer experience

### 12. `-Client` accepts different values in different scripts (S)

Every workstation script uses `'Codex' | 'ClaudeCode' | 'Both'`.
`setup/setup-project.ps1:69` alone uses `'Both' | 'Code' | 'Codex'`. Someone who
learns `-Client ClaudeCode` from the README hits a validation error the first time
they scaffold a project.

**Fix:** standardize on `ClaudeCode`, and accept `Code` as a deprecated alias for one
release.

### 13. `setup/config/` is dead code (S)

`setup/config/setup-config.example.yaml` and `setup/config/setup-schema.json` describe
a full declarative configuration system — languages, required files, validation
checks, troubleshooting entries, MCP components. Nothing reads either file. The only
reference anywhere is a file listing in
`setup/docs/architecture/setup-flowcharts.md:508-509`.

This is a fork in the road, not a cleanup:

- **Implement it** — have `setup-project.ps1` and `setup.ps1` load the YAML so the
  language table (`setup/setup-project.ps1:101-144`) and component list become
  data rather than hardcoded hashtables. This is the more interesting option and
  would make adding C#/Rust/Java/Go starters a config change.
- **Delete it** — if the declarative direction is abandoned, remove both files so
  they stop implying a capability that does not exist.

Pick one. Leaving it as-is is the worst option.

### 14. Four of six advertised languages have no starter (M)

`setup/setup-project.ps1:65` accepts `csharp`, `rust`, `java`, and `go`, and the
README lists them as "supported command profiles". Only `node` and `python` have
starter scripts; the other four hit the warning path at
`setup/modules/ProjectSetup.psm1:754-758` and produce a project with a README, a
`.gitignore`, and nothing else.

**Fix:** either write the four starters (the convention-based
`setup-starter-<language>.ps1` delegation makes this mechanical) or split the
`ValidateSet` so unsupported languages fail fast with a clear message instead of
half-succeeding.

### 15. Missing repository hygiene files (S)

The repo has no `.gitignore`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`,
`CODEOWNERS`, or `.editorconfig`. Consequences:

- `graphify-out/` (and any other local build output) shows up as untracked noise.
- The Node starter it generates sets `license: "MIT"`, but the toolkit itself is
  unlicensed — nobody can legally reuse it.
- A repo that ships security-sensitive provisioning has no disclosure policy.

**Fix:** add all six. The `.gitignore` should at minimum cover `graphify-out/`,
`node_modules/`, `.env`, and `docs-template/artifacts/`.

### 16. The toolkit does not use its own conventions (S)

`setup-project.ps1` generates `CLAUDE.md` and `AGENTS.md` for every new project, and
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
rerunning setup. A `setup/verify.ps1` that checks each component — CLI present and
on PATH, MCP server registered in each client, GitHub token valid and read-only,
Docker engine reachable, Graphify installed — and prints a pass/fail table would be
the single highest-value addition for day-to-day use.

It also gives CI something meaningful to assert after a container `setup` run.

### 20. An uninstall / rollback path (M)

The blueprint's own Stage 4 exit criterion requires that each added component have
"a named owner, update path, and **uninstall path**"
(`setup/docs/architecture/workspace-blueprint.md`). No uninstall exists. Backing out
of claude-mem, Playwright MCP, or a database registration is currently a manual
`claude mcp remove` / `npm uninstall -g` exercise the user has to reconstruct.

**Fix:** `setup/uninstall.ps1 -Component claude-mem,playwright` with the same
`-WhatIf` support as install.

### 21. Idempotency and re-run guarantees (S)

Most installers check `Test-CommandAvailable` and skip, but
`setup/scripts/workstation/install-github-mcp.ps1` deliberately removes and
re-adds the registration each run (`:105-108`, `:115-118`), and
`setup/scripts/workstation/install-claude-mem.ps1` runs `claude-mem install` and
`start` unconditionally. There is no stated contract for what a second run does.

**Fix:** document the intended behavior per component, and add a `-Force` switch for
the cases where re-registration is the point.

### 22. Structured logging and a transcript (S)

Output is `Write-Host` with ANSI colors. A failed setup on someone else's machine
produces nothing shareable.

**Fix:** wrap runs in `Start-Transcript` to a timestamped file under
`setup/logs/` (gitignored), and mention the log path in the failure message.

### 23. Make the Graphify integration first-class (M)

Graphify is installed and registered, and the blueprint places it as one of the four
context layers — but nothing in the toolkit uses it. Natural extensions:

- Have `setup-project.ps1` run an initial `graphify` build on the scaffolded project
  and reference `graphify-out/GRAPH_REPORT.md` from the generated `CLAUDE.md`.
- Ship the post-commit auto-rebuild hook as an opt-in `-EnableGraphifyHook` switch.
- Add `graphify-out/` to the generated `.gitignore` (`New-Gitignore`,
  `setup/modules/ProjectSetup.psm1:87`).

### 24. Cross-platform CI for the container (S)

The container is built `linux/amd64` only. `docs-workflow-local.ps1` already notes
that Apple Silicon needs `--platform linux/amd64`. Adding `linux/arm64` to the
buildx platforms would let Apple Silicon and ARM servers run it natively.

---

## Suggested sequencing

1. **Week 1 — stop the bleeding.** Items 1, 2, 12, 15. All small, all
   user-visible. Add PSScriptAnalyzer (item 5, step 2) at the same time.
2. **Week 2 — make it testable.** Items 5 (steps 1, 3, 4), 6, 7. Once CI exists,
   everything after this is safe to change.
3. **Week 3 — fix the starters.** Items 3, 4, 14. Now covered by item 6's smoke test.
4. **Week 4 — supply chain.** Items 8, 9, 10, 11. Pinning is easiest once CI can
   prove the pins still work.
5. **Ongoing.** Decide item 13 (implement or delete `setup/config/`), then build
   items 19 and 20 — the verify and uninstall commands are what turn this from a
   collection of scripts into a maintainable toolkit.
