# Read-only MCP dependency audit

Run this optional check before trusting MCP launch configuration. It reads explicit local files as data and reports direct dependency selectors. It never invokes configured commands, starts an MCP server, resolves a package, fetches a URL, installs a scanner, changes configuration, or updates registration. It is not wired into provisioning or doctor, and does not change the memory/RAG retention contract.

```powershell
pwsh -NoProfile -File ./setup-llm/scripts/Test-McpDependencies.ps1 -LiteralPath ./.mcp.json
pwsh -NoProfile -File ./setup-llm/scripts/Test-McpDependencies.ps1 -LiteralPath ./.mcp.json -AsJson
pwsh -NoProfile -File ./setup-llm/scripts/Test-McpDependencies.ps1 -LiteralPath ./.codex/config.toml -AsJson
# Multiple inputs from PowerShell:
& ./setup-llm/scripts/Test-McpDependencies.ps1 -LiteralPath @('./.mcp.json', './claude.json') -AsJson
```

Requires PowerShell 7.4 or newer. CI runs the same tests on native Windows, Ubuntu and macOS. No MCP client, Node.js, Docker or network access is needed by the audit.

## Inputs and limits

JSON inputs must be UTF-8 local `.json` and `.jsonc` files with a nonempty top-level `mcpServers` object. JSON is strict; JSONC additionally permits comments and trailing commas. Either may have a UTF-8 BOM. Duplicate keys, invalid encoding, files over 2 MiB, nesting over 64 levels and more than 512 servers fail closed. A server uses `command` (nonempty string), optional `args` (at most 256 strings), optional `type: "stdio"` and optional `env` object with string values. Additional server fields remain unverified; client-specific launch options require an explicit future grammar extension. Tokens longer than 8192 characters or containing NUL/newlines remain unverified.

Native [Codex TOML configuration](https://developers.openai.com/codex/mcp/) is also accepted from explicit `.toml` paths with a nonempty top-level `mcp_servers` table. Its servers use the same classifier, supported server fields and report schema as JSON. Every server is represented, including HTTP servers, disabled entries and entries with extra options. Fields such as `url`, `cwd`, `env_vars`, `enabled` and timeout settings make that server **unverified**; they are not silently discarded.

The dependency-free parser accepts a bounded TOML 1.0 subset: bare/quoted/dotted keys, standard tables, single-line basic and literal strings, standard string escapes, arrays (including comments, newlines and trailing commas), and inline tables with simple keys. Booleans, signed 64-bit decimal integers and decimal floats are accepted as structural data. Keys are case-sensitive. Duplicate keys, repeated tables and conflicting definitions reject the entire input.

Multiline strings, date/time values, nondecimal integers, `inf`/`nan`, arrays of tables and dotted keys inside inline tables are outside this grammar. Unsupported or malformed syntax **anywhere in the file** produces one unverified configuration with no partial server list, including when it occurs in unrelated Codex settings. Parsing is bounded to 64 nesting levels and 65,536 values, with the same 2 MiB and 512-server limits as JSON. Either format may have a UTF-8 BOM; encoding must be strict UTF-8. If necessary, supply a separately prepared supported JSON or TOML input; the tool does not invoke Codex to export configuration.

Other shapes and transports, remote configuration URLs, directories, VS Code `servers`, local package selectors and unsupported launcher syntax remain **unverified**. Input paths are literal, without wildcard expansion. The audit does not discover configuration files or inspect server implementations, environment files, lockfiles or transitive dependencies.

## Classification

| Launch form | Result |
| --- | --- |
| `npx [-y] package` or scoped package without a version | `mutable` |
| npm tag, `latest`, caret, tilde or partial/range selector | `mutable` |
| npm exact SemVer, including valid prerelease/build metadata | `exact-pin` |
| `npx --package=one@1.2.3 -p two@latest -- server-bin` | Each selected package; aggregate `mutable` |
| Recognized Git selector with a full 40-hex commit fragment | `exact-pin` for direct Git identity |
| Git branch, tag, abbreviated commit or missing ref | `mutable` |
| Arbitrary remote package archive | `unverified` |
| `docker run` with an image tag or implicit latest | `mutable` |
| `docker run` with a full SHA-256 digest | `exact-pin` |
| Unknown local executable, shell string, remote bootstrap, unsupported options or environment reference | `unverified` |

The bounded npm grammar accepts `-y`, `--yes`, `--no`, `--ignore-scripts`, `--offline`, repeated `-p package`, `--package package`, `--package=package`, `-p=package`, and the `--` separator. With package flags, the following positional token is the program; otherwise it is the package. Subsequent server arguments are not interpreted as additional dependencies. Options before the program that are outside this grammar stay unverified, including command strings (`-c`).

The Windows wrapper must be tokenized as `command: "cmd"` (or a path ending in `cmd.exe`) and `args: ["/c", "npx", "-y", "package"]`. A single shell string is unsupported. Shell metacharacters invalidate the wrapper. Direct paths with spaces, such as `C:\Program Files\nodejs\npx.cmd`, are recognized by basename; the tool does not attest which executable that path contains.

Docker support is `run`, optional `--`, flags `--rm`, `-i`, `-t`, `-it`, `-ti`, `--init`, and value-bearing `-e`/`--env`, `--name`, `--network`, `-v`/`--volume`, `--mount`, `-w`/`--workdir`, `-u`/`--user`, `--entrypoint`, `--pull`. Long value flags may use `=value`. Other Docker subcommands and options stay unverified. Option values are skipped, never echoed. Commands after the image are outside direct image selection.

## Output and interpretation

JSON schema version 1 has `scope: "direct-launch-selectors-only"`, an aggregate `classification`, and a `configurations` array. Each configuration has a 1-based `input` index, classification, fixed `reasonCode`, and `servers` array. Each server reports its label, launch type, classification, dependencies (kind, projected selector, classification, reason code), environment reference names and remediation. Arrays remain arrays even with one item. Server labels outside a bounded ASCII identifier become `server-N`.

Aggregate order is unverified, then mutable, then exact-pin. Exit code **0** means every inspected direct selector is exact; **1** means any mutable/unverified finding, including unreadable or malformed input; **2** means no inputs were supplied. Unsupported input is never represented as an empty successful audit.

Reports omit raw paths, command lines, arbitrary arguments, environment values and parser exceptions. Git/remote URLs are replaced with fixed text, retaining only an exact Git commit where present. npm mutable versions are projected as `[mutable]`. Environment references in the forms `$NAME`, `${NAME}` and `%NAME%` are listed by name without evaluation; their presence prevents exact classification. Do not put secrets in server labels or dependency names: those identifiers are displayed. Reports cannot identify every secret that happens to look like a package/image name.

**An exact direct pin is not proof of trusted provenance, transitive reproducibility, safe runtime permissions or absence of vulnerabilities.** A mutable selector is not evidence of a vulnerability. This tool does not check whether a version/digest exists. Review and configuration changes remain explicit operator decisions; the existing memory server is intentionally not pinned by this change.

## Verification and provenance

Regression tests live in `setup-llm/ai-cluster/tests/mcp-dependencies.Tests.ps1`. They run the real entry point in both output modes, check input hashes and secrets, and supply process-marker and loopback TCP canaries that must remain untouched. No discovered launcher is executed, including npx or Docker.

The mechanism was informed by [ECC mcp-dependency-review at f390400](https://github.com/affaan-m/ECC/blob/f3904009440af24f00617343910ee89714df8be3/skills/mcp-dependency-review/SKILL.md). This is an original bounded PowerShell implementation; no ECC text/code was copied and no ECC dependency or installation is introduced.
