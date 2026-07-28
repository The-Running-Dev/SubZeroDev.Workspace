# todo-to-github MCP server — build plan

Companion to `todo-to-github-mcp-SPEC.md`. Section references point there.

Deliberately not written in the todo-to-github format — these are engineering
tasks, not user stories, and forcing "As a…" onto them would add noise.

**Before starting:** settle the auth model (Spec §5, §16.1). Phase 2 onward
depends on it.

---

## Phase 0 — Verify the ground

Two things in the spec were true when written and move quickly.

- [ ] Confirm FastMCP 3.x is still the recommended base and note the current
      version. Check whether the official `mcp` SDK v2 has left beta; if it has,
      re-evaluate §4 before writing code rather than after.
- [ ] Confirm the GitHub sub-issue GraphQL mutation and Projects v2 field-write
      API are unchanged. Check `addSubIssue`, issue types, and
      `updateProjectV2ItemFieldValue` against current docs.
- [ ] Record anything that has moved, in the repo, before proceeding.

---

## Phase 1 — Skeleton and the ported core

- [ ] Scaffold the layout in §4. Python 3.11+, `uv`, `pyproject.toml`.
- [ ] Copy `parse_todo.py` and `sync_lib.py` **unchanged**. Adjust imports only.
- [ ] Copy `test_parse_todo.py` and `test_sync_lib.py` **unchanged**.
- [ ] Run them. All must pass with no edits to either the source or the tests.
      If any fail, the copy is wrong — do not fix the test.
- [ ] Bare FastMCP app that starts on stdio and lists zero tools.
- [ ] Wire the MCP Inspector and confirm it connects.

**Gate:** ported suite green, server starts, Inspector connects.

---

## Phase 2 — GitHub access layer

- [ ] `errors.py` — the taxonomy in §10.
- [ ] Token resolution in one function (§5): environment default, per-call
      override. Everything else calls that function, nothing reads the
      environment directly.
- [ ] `httpx` async client with rate-limit handling and retry-with-jitter (§7).
- [ ] `fetch_managed_issues` — issues labelled `gh-todo-sync`, all states, with
      parent and issue type. **Output dict shape must match what
      `sync_lib.build_actions` already consumes.** Verify against
      `test_sync_lib.py`'s fixtures.
- [ ] `fetch_project` — id, fields with options and iteration configs, items
      keyed by issue number.
- [ ] Write path: `create_issue`, `edit_issue`, `set_issue_state`, `set_parent`,
      `add_to_project`, `set_project_field`.
- [ ] Label and milestone existence pre-check (§10) — returns missing names,
      does not create anything.
- [ ] Tests against a mocked transport: URLs, bodies, label and assignee deltas
      (add/remove, not replace), GraphQL mutation shapes.
- [ ] Test that no token value appears in any result or error string.

**Gate:** can read and write a real repo from a script, not yet through MCP.

---

## Phase 3 — Plan store

- [ ] `planstore.py` — in-memory, keyed by opaque random `plan_id`.
- [ ] Store repo, actions, state fingerprint, timestamp.
- [ ] 30-minute TTL, single use, evicted on apply.
- [ ] `validate(plan_id)` distinguishing unknown / expired / already applied, so
      the error can say which.
- [ ] State fingerprint comparison for the changed-since-plan check (§6.4).
- [ ] Tests for every rejection path.

**Gate:** a plan cannot be applied twice, late, or against changed state.

---

## Phase 4 — Tool surface

- [ ] `validate` tool — parse and warnings only, no token, no network.
- [ ] `plan` tool per §8. Returns `plan_id`, summary, warnings, markdown, and
      structured actions. Both markdown and actions, not one.
- [ ] `apply` tool per §8. Takes **only** `plan_id` and optional token. It must
      be structurally impossible to apply without a plan.
- [ ] Partial failure returns a `failures` list, not an exception (§8).
- [ ] Warning prominence (§12): lead the markdown with the warning block when
      any warning matches "has no stories" or "bullet(s) in its description".
- [ ] Resources: `todo-to-github://format` and `todo-to-github://example`.
- [ ] Tool descriptions carrying read-only vs writes, the `plan_id` requirement,
      and the free-form content-loss warning (§12).
- [ ] Contract tests via an in-process FastMCP client.

**Gate:** Inspector can run validate → plan → apply against a real repo.

---

## Phase 5 — Round trip against a fake API

The phase that found every serious bug last time. Do not shorten it.

- [ ] Fake GitHub API holding state in JSON, covering the endpoints in §7.
- [ ] **It must return number fields as floats.** That single quirk is what the
      unit tests missed and what broke convergence.
- [ ] Scenario: empty repo → plan → apply → plan again. **Second plan must be
      entirely no-op.** Anything else is a convergence bug; find it before
      moving on.
- [ ] Scenario: edit one task title, tick one checkbox, change one inherited
      field. Assert exactly the expected items update and no others.
- [ ] Scenario: delete an epic from the file. Assert orphans reported, nothing
      touched.
- [ ] Scenario: rename an anchorless item. Assert duplicate-plus-orphan, and
      that the warning is present.
- [ ] Scenario: free-form file (`## Heading` + plain bullets). Assert it parses,
      assert the dropped-bullet and childless-epic warnings fire, assert they
      appear at the top of the rendered markdown.
- [ ] Scenario: partial failure mid-apply. Assert the next plan shows remaining
      work as creates and the rest as unchanged.

**Gate:** every scenario passes; second plan is always no-op.

---

## Phase 6 — Live verification

Nothing before this proves the server works. The fakes were written from the
same docs as the implementation, so they agree with any misreading.

- [ ] Throwaway repo, real token, real project board.
- [ ] Full lifecycle: plan → apply → plan → edit → plan → apply → plan.
- [ ] Verify in the GitHub UI: sub-issue links render as a hierarchy, issue
      types are set, project fields hold the right values.
- [ ] Repo **without** `Epic`/`Story`/`Task` issue types configured — confirm
      the label fallback.
- [ ] A file of 100+ items, to exercise rate limiting.
- [ ] Reconcile every difference from the fake back into the fake.

**Gate:** real repo converges. Until this passes, the server is unproven.

---

## Phase 7 — Packaging

- [ ] stdio entry point, `uvx todo-to-github-mcp`.
- [ ] Streamable HTTP behind a flag, same tool definitions.
- [ ] README: config snippet, auth setup, format summary, the free-form warning.
- [ ] Publish to PyPI.
- [ ] Test from a second MCP client, not the one used during development.

---

## Deferred

Do not build these into the first version:

- OAuth 2.1 (§5C) — leave the seam, not the implementation.
- Multi-repo targeting (§16.4) — larger than it looks.
- Orphan auto-close — only with explicit opt-in, never defaulted on.
- Webhooks or scheduled sync.

---

## Standing constraints

- Never log or echo a token, including in errors.
- Parents always created before children.
- `apply` never callable without a `plan_id`.
- Nothing closed or deleted except a task whose checkbox was ticked.
- Ported files stay ported. If `parse_todo.py` or `sync_lib.py` needs a change,
  that is a signal something else is wrong — check that first.
