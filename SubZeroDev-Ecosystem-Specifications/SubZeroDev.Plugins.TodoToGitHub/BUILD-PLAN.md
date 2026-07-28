# todo-to-github — Build Plan

Companion to `23-todo-to-github-plugin.md`. Merged from the retired
`todo-to-github-mcp-TODO.md`, reordered so the plugin exists before the MCP surface is added to it.

Deliberately not written in the todo-to-github format — these are engineering tasks, and forcing
"As a…" onto them would add noise.

## What changed from the original plan

The original built a standalone MCP server. This builds a **conforming plugin that also serves MCP**,
which reorders the middle: the plugin contract surface comes before the MCP surface, because the MCP
tools are projected from the manifest rather than hand-written.

The auth phase shrinks to nothing — the contract already decided it. Environment variable, no
per-call parameter, no OAuth seam to design. That was the original plan's first blocking decision and
it is now answered.

## Phase 0 — Verify the ground

Two things in the source specification were true when written and move quickly.

- [ ] Confirm the current recommended MCP server framework for Python and note the version. The
      original recommended FastMCP 3.x while the official SDK was mid-rewrite in beta; re-check
      before writing code rather than after.
- [ ] Confirm the GitHub sub-issue GraphQL mutation and Projects v2 field-write API are unchanged —
      `addSubIssue`, issue types, `updateProjectV2ItemFieldValue`.
- [ ] Record anything that has moved, in the repository, before proceeding.

## Phase 1 — Skeleton and the ported core

- [ ] Scaffold a plugin repository per the contract's layout. Python 3.11+, `uv`, `pyproject.toml`.
- [ ] Copy `parse_todo.py` and `sync_lib.py` **unchanged**. Adjust imports only.
- [ ] Copy `test_parse_todo.py` and `test_sync_lib.py` **unchanged**.
- [ ] Run them. All 115 must pass with no edits to source or tests. **If any fail, the copy is wrong
      — do not fix the test.**
- [ ] `plugin.yaml` manifest validating against the contract schema.
- [ ] `manifest` command, working in a bare container.
- [ ] Dockerfile: non-root, no `gh` binary, digest-pinned base.

**Gate:** ported suite green; `manifest` validates and runs with no config, secrets, network, or
mounts.

## Phase 2 — GitHub access layer

- [ ] Error taxonomy mapped onto the contract's exit codes.
- [ ] Token resolution in **one** function reading the environment. Nothing else reads it, and no
      command takes a token parameter.
- [ ] Async HTTP client with rate-limit handling and retry-with-jitter.
- [ ] `fetch_managed_issues` — issues labelled `gh-todo-sync`, all states, with parent and issue
      type. **Output dict shape must match what `sync_lib.build_actions` consumes**; verify against
      `test_sync_lib.py`'s fixtures.
- [ ] `fetch_project` — id, fields with options and iteration configs, items keyed by issue number.
- [ ] Write path: create issue, edit issue, set state, set parent, add to project, set project field.
- [ ] Label and milestone existence pre-check returning missing names; creates nothing.
- [ ] Tests against a mocked transport: URLs, bodies, label and assignee deltas as add/remove rather
      than replace, GraphQL mutation shapes.
- [ ] **Secret canary test:** the token value appears in no result, error, or log line.

**Gate:** can read and write a real repository from a script, before any CLI or MCP exists.

## Phase 3 — Plan store and the approval gate

- [ ] Plan store keyed by an opaque random `plan_id` — not a content hash.
- [ ] Store repository, actions, state fingerprint, timestamp. In-memory is sufficient; plans are
      short-lived by design, and persisting them invites applying something computed hours ago.
- [ ] 30-minute TTL, single use, evicted on apply.
- [ ] Validation distinguishing unknown, expired, and already-applied, so the error says which.
- [ ] State fingerprint comparison for the changed-since-plan check.
- [ ] Tests for every rejection path.

**Gate:** a plan cannot be applied twice, late, or against changed state.

## Phase 4 — CLI commands

The contract surface, before MCP.

- [ ] `validate` — parse and warnings only. No token, no network.
- [ ] `plan` — result envelope with `plan_id`, summary, warnings, and both `plan.json` and `plan.md`
      artifacts.
- [ ] `apply` — takes **only** `plan_id`. Structurally impossible to apply without a plan.
- [ ] Partial failure returns exit `4` with populated `errors[]`, not an exception.
- [ ] Warning prominence: lead the rendered output with the warning block when any warning matches
      "has no stories" or "bullet(s) in its description".
- [ ] `--output-format` and `--dry-run` per the contract's CLI conventions.
- [ ] Logs to **stderr**; stdout carries only the envelope in JSON mode.

**Gate:** `validate → plan → apply` works from the CLI, in the container, against a real repository.

## Phase 5 — Round trip against a fake API

**The phase that found every serious bug last time. Do not shorten it.**

- [ ] Fake GitHub API holding state in JSON, covering the endpoints above.
- [ ] **It must return number fields as floats.** That single quirk is what the unit tests missed and
      what broke convergence.
- [ ] Empty repository → plan → apply → plan again. **The second plan must be entirely no-op.**
      Anything else is a convergence bug; find it before moving on.
- [ ] Edit one task title, tick one checkbox, change one inherited field. Assert exactly the expected
      items update and no others.
- [ ] Delete an epic from the file. Assert orphans reported, nothing touched.
- [ ] Rename an anchorless item. Assert duplicate-plus-orphan and that the warning is present.
- [ ] Free-form file — `## Heading` plus plain bullets. Assert it parses, assert the dropped-bullet
      and childless-epic warnings fire, assert they appear **first** in the rendered output.
- [ ] Partial failure mid-apply. Assert the next plan shows remaining work as creates and the rest
      unchanged.

**Gate:** every scenario passes; the second plan is always no-op.

## Phase 6 — MCP surface

Only now, and it should be small — the tools are projected, not written.

- [ ] `mcp` command serving `validate`, `plan`, and `apply` over stdio.
- [ ] Tool schemas projected from the manifest's `inputSchema`, not hand-written.
- [ ] Namespaced tool names: `subzerodev_todo_to_github_plan`.
- [ ] Tool descriptions carrying read-versus-write, the plan-token requirement, and the free-form
      content-loss warning.
- [ ] Resources: `subzerodev://todo-to-github/format` and `.../example`.
- [ ] Exit `4` projects as a **successful** tool result with populated errors, not a tool error.
- [ ] Artifacts referenced, never inlined.
- [ ] Contract tests via an in-process MCP client.
- [ ] Test with the MCP Inspector.

**Gate:** MCP conformance checks pass; no tool schema contains a credential parameter.

## Phase 7 — Live verification

Nothing before this proves it works. **The fakes were written from the same documentation as the
implementation, so they agree with any misreading of it.**

- [ ] Throwaway repository, real token, real project board.
- [ ] Full lifecycle: plan → apply → plan → edit → plan → apply → plan.
- [ ] Verify in the GitHub UI: sub-issue links render as a hierarchy, issue types set, project fields
      correct.
- [ ] A repository **without** `Epic`/`Story`/`Task` issue types — confirm the label fallback.
- [ ] A file of 100+ items, to exercise rate limiting.
- [ ] Reconcile every difference from the fake back into the fake.

**Gate:** a real repository converges. Until this passes, the plugin is unproven.

## Phase 8 — Conformance and release

- [ ] Full contract conformance suite passes.
- [ ] Container smoke: `manifest`, `validate`, and a fixture-backed `plan`.
- [ ] Signed image and signed manifest attestation.
- [ ] README: configuration, token setup, format summary, the free-form warning.
- [ ] Publish the image; publish to PyPI so the CLI is directly installable.
- [ ] Test from a second MCP client, not the one used during development.

## Deferred

- Multi-repo targeting — larger than it looks.
- Orphan auto-close — only with explicit opt-in, never defaulted on.
- Webhooks or scheduled sync — that is the Automator's job.
- OAuth for a hosted MCP server — brokered mode covers multi-user through the Automator.

## Standing constraints

- Never log or echo a token, in any output, including errors.
- No command and no projected tool takes a credential parameter.
- Parents always created before children.
- `apply` is never callable without a `plan_id`.
- Nothing closed or deleted except a task whose checkbox was ticked.
- Ported files stay ported. If `parse_todo.py` or `sync_lib.py` needs a change, something else is
  wrong — check that first.
