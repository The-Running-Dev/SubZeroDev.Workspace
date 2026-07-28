# Project Setup Plugin — Build Plan

Companion to `25-project-setup-plugin.md`.

This is **work package W2.7** of `WORK-BREAKDOWN.md`, inside **Phase 2** of `18-roadmap.md`, which
owns phase numbering for the ecosystem. Milestone numbers below are local to this plugin.

Everything generic — exit codes, secrets, envelope, serialization, determinism, configuration,
logging, the manifest — is in the plugin contract and referenced, never restated.

## Before Milestone 0

Two dependencies, and neither is optional.

**W2.6, the shared GitHub client.** This plugin consumes it rather than writing its own. If W2.6 has
not landed, write the client _inside this plugin behind a single module boundary_ and extract it in
W2.6 — one file to move rather than a diffuse rewrite. Do not shell out to `gh`; the Backlog plugin
already settled that with `no gh binary`.

**The contract, tagged.** W0.1 and W0.2. Until it exists, vendor `plugin-manifest.schema.json` and
`result-envelope.schema.json` and record the commit they came from, so re-pointing later is a version
bump rather than an archaeology exercise.

## Ordering principle

**The local half first, and completely.** It is specified by an implementation that already works, it
needs no network, and it is the half that gets used daily — so it is where feedback arrives fastest.
The remote half is riskier and smaller, and it benefits from being built after the plugin's shape has
settled.

One deliberate departure: **the manifest and envelope come first**, because conformance depends on
them and retrofitting an envelope through finished commands is worse than starting with it.

## Milestone 0 — Scaffold and the contract surface

- [ ] Node 24+, strict TypeScript, ESM. Mirror the GitHub plugin's toolchain rather than choosing
      again; the point of a reference implementation is that the second plugin does not re-decide.
- [ ] `plugin.yaml` validating against the manifest schema — it already does, keep it that way
- [ ] `manifest` command, working in a bare container: no configuration, no secrets, no network, no
      mounts
- [ ] Result envelope emission, `--output-format json`, logging to **stderr**
- [ ] Exit codes wired, including `7` and `8` from the manifest
- [ ] `.gitattributes` pinning LF, and the cross-platform CI matrix

**Exit:** `manifest` runs in a bare container and validates; stdout carries exactly one JSON document
with logging forced to `trace`; the full check suite is green on Windows and Linux.

## Milestone 1 — Settings, inference, and `validate`

- [ ] `.settings` text reader — `key = value`, `#` comments, comma-separated lists
- [ ] `.settings.json` reader, and a JSON Schema for it
- [ ] Precedence per the contract, with JSON over text where both define a key
- [ ] Inference: name, description from the README's first prose line, owner from `origin` or the
      authenticated user, license from a `LICENSE` file, default branch
- [ ] **Minimal stack detection** — see below. Behind a module boundary, so the build plugin's
      `detect` replaces it without touching callers
- [ ] `validate` command

**Minimal stack detection means exactly this and no more:** the presence of `package.json`,
`pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `*.csproj`, `*.psm1`, or `Dockerfile`,
mapped to a language and a topic list. No version parsing, no dependency reading, no framework
detection. Anything past that is the build plugin's job and will have to be deleted.

**Exit:** a directory with a README and no settings file produces a complete desired state; malformed
settings fail with exit `2` and a stable message; no configuration path can carry a token value.

## Milestone 2 — `scaffold`, the local half

The largest milestone, and the one specified by an implementation that already works.

- [ ] Directory structure and seed files: `.gitignore`, `.env.example`, `README.md`,
      `ARCHITECTURE.md`
- [ ] **`AGENTS.md` and `CLAUDE.md`** — the repository-specific body plus the shared conventions
      block, generated from one source (see the resolved question below)
- [ ] `.gitattributes`
- [ ] Language starter files
- [ ] Git initialization and optional first commit
- [ ] Build and test validation
- [ ] `--force` semantics: overwrite only when asked, and **refuse `--force` when the working tree is
      dirty**, so a second run cannot destroy uncommitted work

Behaviour is taken from `Setup.psm1`'s exports, function by function, as the specification's table
records. Where this implementation and that script disagree, the script is right unless the
difference is deliberate and written down.

**Exit:** a scaffolded project builds and tests green; a second `scaffold` is a no-op; `--force` on a
dirty tree is refused; generated `AGENTS.md` carries the shared block byte-identically to its source.

## Milestone 3 — Plan store and the approval gate

- [ ] Plan store keyed by an opaque random `planId` — **not** a content hash
- [ ] Stores owner, name, desired state, observed state, actions, fingerprint, timestamps
- [ ] TTL, single use, evicted on apply whatever the outcome — a partially applied plan is stale by
      definition
- [ ] Rejection paths distinguish unknown, expired, already-used, and fingerprint-mismatch, each with
      its own message and exit code
- [ ] The plan file contains no credential

**Exit:** a plan cannot be applied twice, late, or against changed state, and each refusal says which.

## Milestone 4 — GitHub adapter and `plan`

- [ ] Repository read: existence, settings, topics, rulesets
- [ ] **Observed check contexts** from recent default-branch commits — the required-check inference,
      which is observation and never job-name parsing
- [ ] Desired-versus-observed diff producing the action list
- [ ] Rendering a human reviews, with a proposed public repository marked unmissably
- [ ] Rate limits, retries, and redaction via the shared client

**Exit:** planning an existing repository that matches its settings yields zero actions; planning an
absent one yields a create; no required check is proposed that was not observed; a repository with no
history yields no required checks at all, stated as such.

## Milestone 5 — `apply`, the remote half

- [ ] Repository creation with description, homepage, topics, visibility
- [ ] Settings reconciliation for an existing repository
- [ ] Ruleset creation and update on the default branch
- [ ] `origin` wiring, default branch, first push
- [ ] Partial failure: exit `4`, `errors[]` naming which actions succeeded, plan consumed

**Exit:** a throwaway repository is created, configured, protected, and pushed to; a partial failure
reports accurately and does not replay.

## Milestone 6 — Live verification

**Nothing before this proves it works.** The fakes are written from the same reading of the API as
the implementation, so they agree with any misreading of it.

- [ ] A real throwaway repository, end to end: `scaffold` → `plan` → `apply` → `plan` again
- [ ] The second plan must be **entirely no-op**
- [ ] Verify in the GitHub UI: ruleset present and active, topics set, merge strategies correct
- [ ] A repository that already exists and differs — confirm reconciliation rather than failure
- [ ] Fold every correction back into the fixtures

**Exit:** a real repository converges, and the second plan is empty.

## Milestone 7 — Conformance and release

- [ ] Contract conformance suite passes
- [ ] Container smoke: `manifest`, `validate`, and a fixture-backed `plan`
- [ ] Secret canary in no output, log, artifact, error, plan file, or image layer
- [ ] Signed image and signed manifest attestation
- [ ] Documentation: settings reference, inference table, what the gate does and why
- [ ] Publish

## Pull request sequence

| PR  | Milestone                          |
| --- | ---------------------------------- |
| 1   | M0 scaffold and contract surface   |
| 2   | M1 settings, inference, `validate` |
| 3   | M2 `scaffold`                      |
| 4   | M3 plan store and gate             |
| 5   | M4 adapter and `plan`              |
| 6   | M5 `apply`                         |
| 7   | M6 live verification and fixtures  |
| 8   | M7 conformance, signing, release   |

## Definition of done

- Every acceptance criterion in `25-project-setup-plugin.md` is met
- No write path is reachable without a plan token whose fingerprint still matches
- No required status check is ever proposed that was not observed
- A second run of anything is a no-op
- The manifest declares no capability the commands do not exercise
- Stack detection sits behind one module boundary, ready for the build plugin to replace
- The plugin passes contract conformance and runs standalone with no host present
