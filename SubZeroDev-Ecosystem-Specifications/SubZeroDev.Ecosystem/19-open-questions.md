# Open Questions

Questions answered since the first draft are recorded in Resolved below, so the reasoning is not lost
and nobody reopens them by accident.

## Open

**One item, and it is owned outside this workspace:** the Docker plugin's builder — rootless
BuildKit, Buildah, or Kaniko — and whether ContainerPSGenerator becomes manifest-driven before or
after its inference path.

Everything else is decided and recorded below, or in the document that owns it. Where a decision
rests on an assumption that could change, the document states what would change it.

## Resolved

| Question                                                      | Resolution                                                                                                        |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Where does the plugin contract live?                          | Its own repository, versioned and tagged independently                                                            |
| How does Platform come into existence?                        | Minimal Platform alongside Automator — six packages, rest deferred                                                |
| Which packages belong in the near-term Platform?              | Abstractions, Core, Hosting, Persistence, Observability, Testing                                                  |
| Is multi-tenancy required from the first schema?              | Carry the tenant column from the start; defer the feature to Phase 8                                              |
| Repository layout                                             | Platform, Automator, contract, and one repository per substantial plugin                                          |
| Are specifications copied between repositories?               | **No.** One home, referenced by tag                                                                               |
| Build order                                                   | GitHub → Documentation plugin → Automator MVP                                                                     |
| Which plugin is second?                                       | Documentation — the image exists, so it tests the contract cheaply                                                |
| Is local execution the initial product?                       | Yes; Docker host only, local process host deferred to Phase 6                                                     |
| Is the local process host in the MVP?                         | No — it cannot enforce declared capabilities                                                                      |
| Manifest serialization                                        | YAML authoring, canonical JSON for validation and signing                                                         |
| Is JSON Schema the canonical input/output definition?         | Yes — schemas are normative, generated types are not                                                              |
| Are multiple runtime implementations allowed in one manifest? | Yes; resolved by explicit request, then policy, then manifest order                                               |
| Version compatibility policy                                  | Same major accepted, higher major refused; unknown capability and secret keys refused                             |
| Exit codes                                                    | One table, in the contract only                                                                                   |
| Execution states                                              | Six, not thirteen                                                                                                 |
| Workflow event naming                                         | Dotted `<Product>.<Aggregate>.<PastTenseVerb>`, catalogued once                                                   |
| Artifact identity on re-run                                   | Content-addressed blob shared; registration record per execution                                                  |
| Orphaned executions                                           | Lease and heartbeat; terminal state; never auto-retried                                                           |
| CLI naming                                                    | `subzerodev-<name>` canonical, `sz-<name>` alias                                                                  |
| Introspection command                                         | `manifest`, not `describe` or `capabilities`                                                                      |
| CLI output mode                                               | `--output-format`, with `--json` as the short form                                                                |
| Where do generic decisions live?                              | The contract outranks plugin specifications                                                                       |
| GitHub: owned repositories only in Phase One?                 | Yes                                                                                                               |
| GitHub: forks, archived, organization, contributed            | Forks excluded by default; archived included; organization and contributed deferred                               |
| GitHub: collection profile default                            | `standard`                                                                                                        |
| GitHub: consolidated or per-project output?                   | Consolidated only                                                                                                 |
| GitHub: where do portfolio overrides live?                    | Separate file, keyed on the immutable repository ID                                                               |
| GitHub: retain raw API responses?                             | Optional, off by default, excluded from determinism                                                               |
| GitHub: packages and releases capability flags                | Dropped — GitHub exposes neither                                                                                  |
| Plugin signing and trust root                                 | Sigstore cosign, keyless by default; pinned workflow identity for first-party, operator allowlist for third-party |
| Manifest available before execution                           | Published as a signed OCI attestation, so capabilities are read without running the container                     |
| Revocation                                                    | Operator-driven: digest quarantine, revocation list, allowlist removal. Not cryptographic                         |
| Default capabilities when a plugin declares nothing           | Deny everything, including for first-party                                                                        |
| Capability review                                             | Automatic for first-party; human approval on install for everything else                                          |
| Control plane or agent execution                              | Local in the MVP; always via an agent once agents exist                                                           |
| Event history retention                                       | Append-only for 90 days, then compacted to terminal summaries                                                     |
| Lease and heartbeat                                           | 30-second heartbeat, 120-second lease                                                                             |
| Orphaned container on reconnect                               | Reaped if exited, reconciled if still running                                                                     |
| Quarantine semantics                                          | Prevents new executions; does not cancel running ones                                                             |
| Event replay                                                  | Deferred until the event schema is stable across a release                                                        |
| Log caps                                                      | 100 MB per execution, 1 GB per workflow run                                                                       |
| Automator client surface                                      | PowerShell first; separate CLI with remote agents                                                                 |
| Generated wrappers and modules                                | Produced at install time; generated code is read-only, extensions live alongside                                  |
| Notification preferences                                      | Per tenant and per user, user overrides tenant                                                                    |
| Transport after in-process                                    | Not chosen now; the outbox is transport-agnostic by design                                                        |
| Trace sampling                                                | Executions always sampled; HTTP ratio-sampled at 10%                                                              |
| Telemetry export                                              | Opt-in; console and file by default                                                                               |
| Coverage                                                      | Reported, not enforced, except the contract repository at 90%                                                     |
| End-to-end targets                                            | Recorded fixtures in CI plus a controlled fixture account on a schedule                                           |
| Contract-test corpus                                          | Owned and published by the contract repository, consumed by both sides                                            |
| Documentation site                                            | Architecture repository publishes and owns its pipeline                                                           |
| Plugin template home                                          | The contract repository, not the GitHub plugin                                                                    |
| Does every plugin need a CLI?                                 | Yes, unless remote-API-only, which must still serve a manifest                                                    |
| Multiple runtimes per command                                 | Allowed; resolved by explicit request, then policy, then manifest order                                           |
| JSON output implied on non-TTY?                               | No — always explicit                                                                                              |
| Conformance and publication                                   | Conformance gates publication; no self-certified exemptions                                                       |
| Build plugin `package` command                                | Removed; packaging belongs to the package plugin                                                                  |
| Build toolchains                                              | Present in the image, never installed at run time                                                                 |
| Artifact signing location                                     | Package plugin at pack time; the release plugin only attaches                                                     |
| `push` and `publish` overwrite behaviour                      | Refuse by default; explicit flag required                                                                         |
| Release approval                                              | A workflow concern, not a plugin one                                                                              |
| Forge coverage                                                | One release plugin, provider boundary inside                                                                      |
| Commit activity granularity                                   | Weekly, matching GitHub's own buckets                                                                             |
| AI summaries                                                  | Stored with provenance, never regenerated on read                                                                 |
| Screenshots and badges                                        | External, referenced by URL                                                                                       |
| Billing provider                                              | Paddle first, as merchant of record; swaps behind the Platform abstraction                                        |
| Metered dimensions                                            | Completed executions and stored bytes, never execution minutes                                                    |
| Licence model                                                 | Open-core, feature-tiered, per installation, agents as the paid dimension                                         |
| Community edition licensing                                   | No licence code path at all — not a check that passes                                                             |
| Licence enforcement                                           | Offline verification; expiry degrades features, never data or running work; fails open                            |
| Root namespace                                                | `SubZeroDev` kept; identifiers reserved before first publish                                                      |
