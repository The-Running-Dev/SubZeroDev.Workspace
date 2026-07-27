# SubZeroDev.Automator.Plugins.GitHub

CLI-first GitHub integration plugin that transforms GitHub repository data into
provider-independent, versioned project models.

The plugin lives in this repository but does not depend on the workstation
toolkit or a future automation runtime.

## Development

Requires Node.js 24 or later.

```bash
npm install
npm run lint
npm run typecheck
npm test
npm run build
node dist/cli.js --help
```

### PowerShell runner

The cross-platform [`run.ps1`](run.ps1) script provides the supported local and
Docker workflows. Run it from PowerShell 7 or later.

Install dependencies, run every check, build, and smoke-test the CLI:

```powershell
./run.ps1 -Mode Test
```

Build and run the local CLI. Positional arguments are passed to the CLI. Use
`-CliArgument` when an argument begins with a hyphen:

```powershell
./run.ps1 -Mode Local -CliArgument '--help'
./run.ps1 -Mode Local -SkipInstall validate
```

Build the Docker image and run the CLI:

```powershell
./run.ps1 -Mode Docker -BuildImage -CliArgument '--help'
```

For authenticated commands, set the token in the current process and invoke the
container. The script forwards the environment variable by name; it does not
place the token value in the Docker command:

```powershell
$env:GITHUB_TOKEN = 'github_pat_replace_me'
./run.ps1 -Mode Docker -BuildImage sync
```

Docker mode mounts `.cache/` at `/data/cache` and `output/` at `/data/output`.
Override them with `-CachePath` and `-OutputPath`. Reuse an existing image by
omitting `-BuildImage`, or select another tag with `-ImageName`.

The image runs as UID 10001, so bind-mounted host directories owned by another
user are not writable. On Linux the runner therefore passes the current host
user by default. Override it with `-DockerUser`, or set it explicitly when
invoking Docker directly:

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  --volume "$PWD/.cache:/data/cache" \
  --volume "$PWD/output:/data/output" \
  subzerodev-automator-plugins-github:local validate
```

Docker Desktop on macOS and Windows maps ownership automatically, so no
`--user` flag is needed there.

### Direct Docker commands

The equivalent commands without the PowerShell wrapper are:

```bash
docker build -t subzerodev-automator-plugins-github:local .
docker run --rm subzerodev-automator-plugins-github:local --help
docker run --rm \
  --env GITHUB_TOKEN \
  --volume "$PWD/.cache:/data/cache" \
  --volume "$PWD/output:/data/output" \
  subzerodev-automator-plugins-github:local sync
```

## CLI

```bash
subzerodev-github sync
subzerodev-github list
subzerodev-github stats
subzerodev-github export
subzerodev-github validate
```

Command behavior will be implemented milestone by milestone. The current
scaffold establishes the runner and stable command surface.
