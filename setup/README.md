# Cross-Platform AI Workspace Setup

This directory provides PowerShell scripts for configuring Codex and Claude Code on Windows, macOS, and Ubuntu/Debian, plus a generator for starting consistently structured projects.

## Supported platforms

| Platform | Prerequisite installer | Package tooling |
|----------|------------------------|-----------------|
| Windows | `setup-windows.ps1` | Winget |
| macOS | `setup-macos.ps1` | Homebrew and npm |
| Ubuntu/Debian | `setup-ubuntu.ps1` | apt, pipx, and npm |

Use `setup.ps1` for normal operation. It detects the OS and dispatches to the matching platform script. `setup-workstation.ps1` contains the shared Graphify, memory, and MCP configuration used after platform prerequisites are available.

## Prerequisites

- PowerShell 7 on macOS and Linux; Windows PowerShell 5.1 or PowerShell 7 on Windows
- Winget on Windows, Homebrew on macOS, or `apt-get` plus `sudo` on Ubuntu/Debian
- Docker Desktop or Docker Engine when GitHub MCP is enabled
- A GitHub personal access token for GitHub MCP

Run the scripts as your normal user. Review package installations and third-party integrations before enabling them.

## Workstation setup

From this directory, preview platform prerequisite actions:

```powershell
./setup.ps1 -Client Both -WhatIf
```

Recommended first run without third-party session memory:

```powershell
./setup.ps1 -Client Both -SkipClaudeMem
```

The default setup installs or configures:

- Node.js and the selected assistant CLIs
- GitHub CLI, [`act`](https://nektosact.com/), and Astral `uv`
- Graphify
- Claude Code built-in memory checks
- optional `claude-mem`
- GitHub MCP through Docker Compose
- Playwright MCP

### Select clients

```powershell
./setup.ps1 -Client Codex
./setup.ps1 -Client ClaudeCode
./setup.ps1 -Client Both
```

### Skip optional components

```powershell
./setup.ps1 `
  -Client Both `
  -SkipGraphify `
  -SkipClaudeMem `
  -SkipGitHub `
  -SkipPlaywright
```

### Restrict Filesystem MCP

Filesystem MCP is disabled by default because the assistants already have native file access. When it is required, grant only the smallest practical directory:

```powershell
./setup.ps1 `
  -Client Both `
  -IncludeFilesystem `
  -FilesystemPath '/path/to/project'
```

## GitHub MCP

Copy the environment template and insert a narrowly scoped token locally:

```powershell
Copy-Item docker/.env.example docker/.env
```

Keep these defensive defaults unless broader access is intentional:

```dotenv
GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_replace_me
GITHUB_READ_ONLY=1
GITHUB_TOOLSETS=context,repos,issues,pull_requests,actions
```

`docker/.env` is git-ignored. Never commit or paste the real token into documentation, issues, logs, or chat. Start Docker Desktop on Windows/macOS or Docker Engine on Linux before running the GitHub setup.

To retry only GitHub MCP after supplying the token:

```powershell
./setup.ps1 `
  -Client Both `
  -SkipGraphify `
  -SkipClaudeMem `
  -SkipPlaywright
```

## Create a new project

```powershell
./setup-project.ps1 `
  -ProjectPath '/path/to/MyProject' `
  -ProjectName 'MyProject' `
  -Language 'node'
```

The generator creates common source, test, documentation, environment-example, Git, and assistant-instruction files. Node.js and Python include language starter files; other supported command profiles can be used with `-SkipLanguageStarter` until a dedicated starter is added.

Useful switches include:

- `-Client Both|Code|Codex`
- `-SkipGit`
- `-SkipLanguageStarter`
- `-SkipValidation`
- `-AutoCommit`
- `-WhatIf`

## Troubleshooting

- **Docker CLI exists but the engine is stopped:** start Docker Desktop or the Docker service, wait until `docker info` succeeds, and rerun.
- **GitHub token error:** verify `docker/.env` exists and its token is not the placeholder.
- **New command is not found:** start a new PowerShell session so package-manager PATH changes load.
- **MCP server is not visible:** restart Codex and Claude Code after registration.
- **Fresh-machine preview stops before integrations:** this is expected; `-WhatIf` does not install commands needed to inspect MCP state.

## Detailed documentation

- [Documentation index](docs/index.md)
- [Quick start](docs/getting-started/quickstart.md)
- [New-project workflow](docs/getting-started/new-project.md)
- [Modular architecture](docs/architecture/modular-architecture.md)
- [Setup specification](docs/architecture/setup-specification.md)
- [Language starters](docs/reference/language-starters.md)

## Build the documentation site

Initialize the pinned Docusaurus template after cloning this repository:

```powershell
git submodule update --init --recursive
```

Synchronize `setup/docs` into the template and configure it for this repository's GitHub Pages URL:

```powershell
./setup-docs.ps1
```

The project-owned `docs/sidebars.ts` and `docs/docusaurus.config.ts` files are copied to the root of `docs-template` during production synchronization. Customize those files in `setup/docs`; do not edit the generated submodule working tree. The current navbar override removes the template's CV, Projects, Portfolio, and Demos entries.

Then build locally with the template's declared pnpm version:

```powershell
Set-Location ../docs-template
npx -y pnpm@9.0.0 install --frozen-lockfile
npx -y pnpm@9.0.0 run build:prod
```

The build output is written to `docs-template/artifacts`. The `Documentation Pages` workflow validates the build on pull requests and deploys it from `main` using GitHub Pages Actions. Configure the repository's Pages source as **GitHub Actions** before the first deployment.

To start the Docusaurus development server locally:

```powershell
./docs-local.ps1
```

The local script synchronizes the project documentation and configuration into the existing `docs-template` submodule, then starts Docusaurus from that directory. The resulting submodule changes are generated local output and should not be committed.

The default address is `http://localhost:3000/`. Use `-Port`, `-HostName`, or `-NoOpen` to change the local-server behavior. Use `-SkipInstall` only when the template dependencies are already installed. Stop any older background instance before restarting the script so the server can claim the port.

### Test the GitHub Actions Workflow Locally

The platform setup scripts install [`act`](https://nektosact.com/), which runs GitHub Actions jobs in Docker. Start Docker Desktop or Docker Engine, then run this command from `setup`:

```powershell
./docs-workflow-local.ps1
```

The wrapper simulates a `pull_request` event and executes only the `build` job from `.github/workflows/docs-pages.yml`. That job performs the same checkout, submodule initialization, documentation synchronization, dependency installation, and production Docusaurus build used on GitHub. The Pages configuration, artifact upload, and deployment steps are skipped because they run only for non-pull-request events.

The first run downloads the medium `ubuntu-latest` runner image and can take several minutes. On ARM64 hosts, including Apple Silicon, the wrapper requests `linux/amd64` to match the available runner image. Use `-ReuseRunnerImage` after the image and actions are cached:

```powershell
./docs-workflow-local.ps1 -ReuseRunnerImage
```

Use `docs-local.ps1` for interactive live-reload editing. Use `docs-workflow-local.ps1` before pushing changes when you need to validate the GitHub Actions build itself. `act` is a close local approximation of GitHub-hosted runners, but it does not implement every GitHub Actions feature.
