# Open Questions

Questions answered since the first draft are recorded in Resolved below, so the reasoning is not lost
and nobody reopens them by accident.

## Open

### Plugin contract

1. What signing mechanism is planned? This blocks two of the four trust levels — "signed third-party"
   and "untrusted" are currently unimplementable, so the contract exposes only first-party and
   development-local. Needs an ADR covering mechanism, trust root, key distribution, verification
   point, revocation, and offline behaviour.
2. Does every plugin need a CLI, or may a plugin be remote-API-only?
3. How are runtime-specific options represented without leaking host detail into the manifest?
4. May one manifest declare multiple runtimes for the same command, and if so how does the host choose
   deterministically?
5. Should JSON output be implied when stdout is not a TTY, or always explicit? Implicit is friendlier
   to adapters; explicit is harder to get wrong, and a wrong guess silently corrupts output.

### Automator

1. Does the control plane execute plugins directly, or always dispatch to an agent? This changes where
   capability enforcement lives.
2. What are the default network and filesystem restrictions for a first-party plugin that declares
   nothing?
3. Is execution event history append-only forever, or compacted after a retention window?
4. What are the default lease duration and heartbeat interval for orphan detection?
5. Are plugins installed globally, per project, or per tenant?
6. What is the first remote-agent transport?
7. Does quarantining a plugin version cancel executions already running on it, or only prevent new
   ones?

### Platform

1. Is `SubZeroDev.Platform` the final root name?
2. Should identity be based on ASP.NET Core Identity initially?
3. Which billing provider first — Stripe or Paddle?
4. Which license model is expected?
5. Is there a default OTLP collector in self-hosted deployments, or is exporting opt-in?

### Testing and release

1. Is there a coverage threshold, and is it enforced or only reported?
2. Does the conformance suite gate publication, or only report?
3. Does `npm audit`, or its equivalent per ecosystem, block a release?

### Plugins

1. **Docker plugin:** which builder — rootless BuildKit, Buildah, or Kaniko? This decides whether
   Docker socket access is ever granted at all, and is the most consequential open question in the
   tooling set. _Owned outside this workspace._
2. **ContainerPSGenerator:** manifest-driven generation first, or keep `--help` inference primary?
   _Owned outside this workspace._
3. **Build plugin:** is `package` its job, or purely the package plugin's? Both currently claim it.
4. **Requirements Compiler:** which AI provider is first, and should publishing require human
   approval beyond dry-run-by-default?
5. **GitHub plugin:** should commit activity be grouped by week, month, or year?

## Resolved

| Question                                                      | Resolution                                                                            |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Where does the plugin contract live?                          | Its own repository, versioned and tagged independently                                |
| How does Platform come into existence?                        | Minimal Platform alongside Automator — six packages, rest deferred                    |
| Which packages belong in the near-term Platform?              | Abstractions, Core, Hosting, Persistence, Observability, Testing                      |
| Is multi-tenancy required from the first schema?              | Carry the tenant column from the start; defer the feature to Phase 8                  |
| Repository layout                                             | Platform, Automator, contract, and one repository per substantial plugin              |
| Are specifications copied between repositories?               | **No.** One home, referenced by tag                                                   |
| Build order                                                   | GitHub → Documentation plugin → Automator MVP                                         |
| Which plugin is second?                                       | Documentation — the image exists, so it tests the contract cheaply                    |
| Is local execution the initial product?                       | Yes; Docker host only, local process host deferred to Phase 6                         |
| Is the local process host in the MVP?                         | No — it cannot enforce declared capabilities                                          |
| Manifest serialization                                        | YAML authoring, canonical JSON for validation and signing                             |
| Is JSON Schema the canonical input/output definition?         | Yes — schemas are normative, generated types are not                                  |
| Are multiple runtime implementations allowed in one manifest? | Yes; deterministic selection is still open                                            |
| Version compatibility policy                                  | Same major accepted, higher major refused; unknown capability and secret keys refused |
| Exit codes                                                    | One table, in the contract only                                                       |
| Execution states                                              | Six, not thirteen                                                                     |
| Workflow event naming                                         | Dotted `<Product>.<Aggregate>.<PastTenseVerb>`, catalogued once                       |
| Artifact identity on re-run                                   | Content-addressed blob shared; registration record per execution                      |
| Orphaned executions                                           | Lease and heartbeat; terminal state; never auto-retried                               |
| CLI naming                                                    | `subzerodev-<name>` canonical, `sz-<name>` alias                                      |
| Introspection command                                         | `manifest`, not `describe` or `capabilities`                                          |
| CLI output mode                                               | `--output-format`, with `--json` as the short form                                    |
| Where do generic decisions live?                              | The contract outranks plugin specifications                                           |
| GitHub: owned repositories only in Phase One?                 | Yes                                                                                   |
| GitHub: forks, archived, organization, contributed            | Forks excluded by default; archived included; organization and contributed deferred   |
| GitHub: collection profile default                            | `standard`                                                                            |
| GitHub: consolidated or per-project output?                   | Consolidated only                                                                     |
| GitHub: where do portfolio overrides live?                    | Separate file, keyed on the immutable repository ID                                   |
| GitHub: retain raw API responses?                             | Optional, off by default, excluded from determinism                                   |
| GitHub: packages and releases capability flags                | Dropped — GitHub exposes neither                                                      |
