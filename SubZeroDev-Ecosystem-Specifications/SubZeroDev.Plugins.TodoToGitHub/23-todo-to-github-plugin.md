# todo-to-github Plugin

| Field     | Value                                        |
| --------- | -------------------------------------------- |
| Plugin ID | `subzerodev.todo-to-github`                  |
| CLI       | `subzerodev-todo-to-github`, alias `sz-todo` |
| Contract  | `SubZeroDev.PluginContract` 1.0              |
| Language  | Python 3.11+                                 |
| Status    | Specified; ports an existing working skill   |
| Source    | `reference/todo-to-github.skill`             |

Merged from `todo-to-github-mcp-SPEC.md` and its build plan, both retired. This document describes
the capability as a **conforming plugin**; the MCP surface it gains is projected, and specified in
`SubZeroDev.MCP/21-mcp-tool-projection.md`.

Everything generic — exit codes, secret handling, envelope, determinism, configuration, logging — is
in the contract and referenced here, never restated.

## Purpose

Turn a structured markdown todo file into a GitHub epic → story → task hierarchy with real sub-issue
links, labels, assignees, milestones, and Projects v2 field values.

Re-runnable: it inspects what exists, updates only what differs, leaves matching items alone.

## Why this is the right second plugin

It exercises far more of the contract than a documentation build does, and it does so in a second
language:

| Contract surface              | Exercised because                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| Language neutrality           | Python, where the first plugin is Node. A second Node plugin would prove much less |
| Idempotency and `conditional` | Its whole design is convergence — a second run must be a no-op                     |
| Partial success, exit `4`     | A 200-item file will partly fail, and that is a normal outcome                     |
| Dry run and approval          | It writes to a system other people can see                                         |
| MCP projection                | The first plugin needing a direct AI-client surface                                |
| Determinism                   | Its known bugs were convergence failures, and it has the regression tests          |

It also arrives with a working implementation and 115 passing tests, so the contract is being tested
against real code rather than against a fresh design that was written to fit it.

## What ports unchanged

Four files carry the domain model and every fix found during skill testing. They copy verbatim:

| File                 | Role                                   |
| -------------------- | -------------------------------------- |
| `parse_todo.py`      | markdown → normalized item list        |
| `sync_lib.py`        | markers, hashing, diff, plan rendering |
| `test_parse_todo.py` | 60 tests                               |
| `test_sync_lib.py`   | 55 tests                               |

**The ported suite must pass with no edits to either the source or the tests.** A failure means the
port changed something it should not have; fix the port, never the test.

`gh_sync.py` does **not** port. It is built around local execution — cwd repo resolution, file paths,
a `gh` binary on `PATH` — and the plugin replaces it with direct API access.

## Commands

| Command    | Idempotency   | Writes  | Notes                                 |
| ---------- | ------------- | ------- | ------------------------------------- |
| `validate` | `idempotent`  | No      | Parse and warn. No token, no network  |
| `plan`     | `idempotent`  | No      | Compute the diff, return a plan token |
| `apply`    | `conditional` | **Yes** | Takes only a plan token               |
| `manifest` | `idempotent`  | No      | Contract requirement                  |
| `mcp`      | —             | —       | Serve the above over MCP stdio        |

`apply`'s idempotency condition, stated as the contract requires: **idempotent when the target state
already matches the plan; refuses when the repository has changed since the plan was computed.**

### The plan-apply gate

`apply` accepts only a `plan_id`. It takes no todo file, no repository, and nothing else that would
let it act without a plan.

A plan is opaque and random — not a hash of its content — single-use, TTL-bounded at 30 minutes, and
carries a fingerprint of the repository state it was computed against. `apply` refuses a plan that is
unknown, expired, already used, or whose repository has changed.

The fingerprint check is the one that earns its keep: between plan and apply, someone may have edited
an issue in a browser. Applying a stale diff over their edit is worse than refusing.

**Why structural rather than documented.** In the skill this was a paragraph asking the model to stop
and wait. That works when the skill file is loaded alongside; a different client's model never reads
it. Under MCP the gate must be structural or it does not exist — and an injected instruction in a
todo file cannot fabricate a plan token.

## GitHub access

**REST and GraphQL directly. Not the `gh` binary.**

Three reasons, in order of weight: a container with a `gh` dependency inherits a version matrix and
`gh`'s own auth resolution competing with the plugin's; two of the four bugs found in skill testing
were `gh`-version-dependent, and calling the API deletes that class entirely; and the label and
assignee delta logic is a JSON body rather than subprocess argument construction.

Concretely: an async HTTP client, REST for issues and milestones, GraphQL for sub-issue links, issue
types, and Projects v2.

**Keep the observed-issue dict shape identical** to what `gh issue list --json` produced. `sync_lib`
consumes it and its tests assert on it; changing the shape means rewriting tested code for nothing.

**Rate limiting.** A 200-item file is several hundred calls. Honour `X-RateLimit-Remaining`, back off
on secondary limits, retry 5xx with jitter. The skill never needed this because `gh` handled it.

**Ordering.** Parents before children, always. `build_actions` already emits actions in that order.

## Authentication

`GITHUB_TOKEN` from the environment, per the contract. **No token parameter on any command or
projected tool** — see `SubZeroDev.MCP/adr/ADR-001` for why an MCP tool argument is a worse place for
a credential than `argv`, which the contract already forbids.

Scopes: `repo` for issues, `project` for Projects v2 field writes. Insufficient scope fails at
startup with the missing scope named, not partway through an apply.

## Known bugs — keep them fixed

Four surfaced during skill testing. Three were invisible to unit tests and appeared only under a
simulated round trip. Every one has a regression test in the ported suite.

1. **Numeric field never converges.** GitHub returns number fields as floats (`5.0`); the file
   supplies strings (`"5"`). String comparison reports a change forever. Fixed by
   `sync_lib.values_equal` — the API layer must not re-stringify field values on the way in.
2. **Unreadable parent loops.** When the parent field cannot be read, every child looks permanently
   changed while producing no command to fix it — a silent infinite no-op. Direct API access should
   make parent readable, so pass `compare_parent=True`, but keep the parameter and its tests.
3. **Silent content loss on free-form input.** A `## Heading` plus plain bullets parses cleanly and
   produces one empty epic per heading, discarding every bullet. No error. **This is the most
   dangerous failure mode**, and its mitigation is warnings that must reach the caller — see below.
4. **Orphan sort order.** Cosmetic; sorted by key rather than issue number.

## Warnings must be unmissable

Bug 3 causes total content loss with no error, and the mitigation only works if the caller sees it.

- `warnings[]` is top-level on the result envelope, never nested.
- When any warning matches "has no stories" or "bullet(s) in its description", the rendered output
  **leads with the warning block**, before the summary. Under MCP this is not cosmetic: the model
  sees one blob and summarizes it, so anything after the summary may never reach a human.
- `plan`'s command and tool descriptions both state that a free-form file may parse and produce
  almost nothing, and that item counts should be checked against the source.

A caller that ignores all three has been told three times.

## Defaults for multi-caller use

Two behaviours were chosen for one local user and are riskier when the caller is not the person who
wrote the file.

**Drift reconciliation defaults to off.** The skill defaults it on — the todo file wins, and an issue
edited in a browser is reset. Under a shared server or an AI client that silently reverts someone
else's work. It remains available as an explicit parameter.

**Orphans are reported, never actioned.** No auto-close, and no parameter enabling it by default.

## Artifacts

| Artifact            | Content                                                        |
| ------------------- | -------------------------------------------------------------- |
| `plan.json`         | Structured actions, for a caller rendering its own view        |
| `plan.md`           | Rendered plan from `sync_lib.render_plan`                      |
| `apply-report.json` | Created, updated, fields set, skipped, issue numbers, failures |

Both `plan.json` and `plan.md` exist deliberately: text-only callers need the second, anything
building UI needs the first.

## Failure handling

`apply` returning failures is exit `4`, not an exception. A partial apply is a normal outcome:
report what succeeded, what did not, and why. The content markers make re-planning after a partial
failure safe — that is what they are for.

**Label and milestone existence is pre-checked during `plan`**, with missing names in `warnings`.
The skill discovers this halfway through creating issues; the plugin must not.

## Resources

Projected as MCP resources and shipped in the container:

- `subzerodev://todo-to-github/format` — the input format specification
- `subzerodev://todo-to-github/example` — a complete worked example

A calling model needs the format to convert a user's file. Serving it as a resource beats duplicating
it into every tool description, where it would be both long and prone to drift.

## Out of scope

- Creating labels and milestones. Pre-check and fail; do not create.
- Writing back to the todo file. One direction only.
- Converting free-form files. The plugin parses and warns; it does not guess. Conversion is the
  calling model's job, informed by the format resource.
- Webhooks or scheduled sync. Every run is caller-initiated — scheduling is the Automator's.
- Multi-repo targeting. One file, one repository. Larger than it looks.

## Open questions

1. **Multi-repo targeting** — one file per repository as today, or per-epic repository targeting.
   Assume single-repo unless decided; it is a much larger change than it appears.
2. Does this plugin share a GitHub provider library with the GitHub plugin? They point in opposite
   directions — one reads portfolio metadata, one writes issues — but both need auth, rate limiting,
   and retry. Recommendation: **no shared library yet.** Two plugins, one provider each; extract only
   if a third appears, on the same reasoning as Platform extraction.
