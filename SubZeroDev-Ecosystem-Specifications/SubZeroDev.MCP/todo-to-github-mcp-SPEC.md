# todo-to-github MCP server — specification

Port of the `todo-to-github` skill to an MCP server, so it can be called from
clients other than Claude Code.

This document assumes the reader has the existing skill directory available.
Where it says "port unchanged", that is meant literally — copy the file, do not
rewrite it.

---

## 1. What this is

Takes a structured markdown todo file and creates a GitHub epic → story → task
hierarchy with real sub-issue links, labels, assignees, milestones, and GitHub
Projects field values. Re-runnable: it inspects what exists, updates only what
differs, and leaves matching items alone.

The skill version works. This port exists for one reason — reach to other MCP
clients. It is not a rewrite, and any change beyond what Section 3 requires
should be justified against that.

---

## 2. What ports unchanged

Copy these four files as-is. They are pure functions with no I/O, no subprocess,
and no filesystem access:

| File | Role |
|---|---|
| `scripts/parse_todo.py` | markdown → normalised item list |
| `scripts/sync_lib.py` | markers, hashing, diff, plan rendering |
| `tests/test_parse_todo.py` | 60 tests |
| `tests/test_sync_lib.py` | 55 tests |

These carry the whole domain model and every bug fix found during skill testing.
The test suite must pass unmodified after the port. If it does not, the port
changed something it should not have.

`scripts/gh_sync.py` does **not** port. It is built around local execution —
cwd-based repo resolution, file paths, a `gh` binary on PATH. Sections 4–7
replace it.

`references/input-format.md` and `assets/example-todo.md` port unchanged and
should be exposed as MCP resources (Section 8).

---

## 3. What changes, and why

| Concern | Skill (local) | Server |
|---|---|---|
| Repo identity | `gh repo view` reads cwd | required parameter |
| Todo file | path on disk | markdown content in the request |
| Auth | ambient `gh` login | explicit, per Section 5 |
| Approval gate | prose instruction in SKILL.md | enforced by plan token, Section 6 |
| Output | printed markdown | structured result + rendered markdown |

The approval gate is the important one. In the skill it is a paragraph asking
the model to stop and wait. Another client's model will not read that paragraph.
It has to become structural or it does not exist.

---

## 4. Framework and layout

**FastMCP 3.x.** It is the de-facto standard, decorator-based, and supports both
stdio and streamable HTTP from the same code. The official `mcp` SDK shipped a
v2.0.0b1 on 2026-06-30 that replaces its internals for the stateless 2026
protocol; it is beta and mid-rewrite, so not the right base right now. Verify
both are still true at build time — this moves fast.

```
todo-to-github-mcp/
├── pyproject.toml
├── src/todo_to_github_mcp/
│   ├── __init__.py
│   ├── server.py          # FastMCP app, tool definitions, resources
│   ├── parse_todo.py      # ported unchanged
│   ├── sync_lib.py        # ported unchanged
│   ├── github.py          # GitHub access layer (Section 7)
│   ├── planstore.py       # plan token storage (Section 6)
│   └── errors.py          # error taxonomy (Section 10)
└── tests/
    ├── test_parse_todo.py   # ported unchanged
    ├── test_sync_lib.py     # ported unchanged
    ├── test_github.py       # request construction, mocked transport
    ├── test_planstore.py
    └── test_server.py       # tool contracts, in-process client
```

Target Python 3.11+. Runnable with `uv run`.

---

## 5. Auth — decide this first

Everything else follows from it. Three options:

**A. Ambient (`gh` on the host).** Server shells out to `gh`, which uses whatever
login the host has. Zero auth code. Only defensible for a single-user stdio
server on your own machine — the server acts as one identity for all callers.

**B. Per-call token.** Every tool takes a `token` parameter. Trivial to
implement, works for any transport, and callers are explicit about identity. The
cost is a credential in the tool arguments, which means it lands in client logs
and conversation history.

**C. OAuth 2.1.** What MCP standardised for remote HTTP servers (spec revision
2025-06-18); FastMCP ships helpers. Correct for a genuinely multi-user hosted
server. Substantially more work.

**Recommendation — mine, not a decision you have made:** build for A and B
together. A single `GITHUB_TOKEN` environment variable at startup, overridable
by an optional per-call `token` parameter. That covers local stdio use today and
shared use tomorrow without an OAuth flow. Leave a seam for C: keep token
resolution in one function so it can be swapped for a request-context lookup
later.

Whatever you pick, **the token is never logged and never echoed in a tool
result**, including in error messages. Add a test for that.

Minimum scopes: `repo` for issues, `project` for Projects v2 field writes.
Fail at startup with a clear message if the token lacks them, rather than
partway through an apply.

---

## 6. The plan token — the approval gate

Two tools, `plan` and `apply`. `plan` is read-only. `apply` writes.

`apply` must not be callable without a plan the user has seen. Enforce it:

1. `plan` computes the actions, stores them, and returns a `plan_id` — an opaque
   random string, not a hash of the content.
2. `apply` takes only a `plan_id`. It does not take a todo file, a repo, or any
   parameter that would let it act without a plan.
3. A stored plan carries the repo, the fetched state fingerprint, and a
   timestamp.
4. `apply` rejects a plan that is: unknown, already applied, older than the TTL,
   or whose repo state has changed since the plan was computed.

That last check matters. Between plan and apply someone may have edited an issue
in the browser. Re-fetch the managed issue set on apply and compare against the
fingerprint taken at plan time; on mismatch, refuse and tell the caller to
re-plan. Failing loudly here is much better than applying a stale diff.

**Storage:** in-memory dict keyed by `plan_id` is sufficient. Plans are
short-lived by design. TTL 30 minutes, single-use, evict on apply. Persisting
plans invites applying something computed hours ago.

This does not stop a determined caller from chaining `plan` then `apply` without
showing anyone. Nothing can. What it does stop is `apply` firing on a repo where
no plan was ever computed, which is the failure that actually costs something.

---

## 7. GitHub access layer

**Use the REST and GraphQL APIs directly, not the `gh` binary.** Reasons:

- Shelling out to `gh` on a server means a binary dependency, a version matrix,
  and `gh`'s own auth resolution fighting yours.
- Two of the four bugs found during skill testing were `gh`-version-dependent
  (Section 9). Calling the API directly deletes that entire class.
- Argument construction via subprocess is where the label/assignee delta logic
  lives; as API calls it is a JSON body and simpler.

Concretely: `httpx` async client, REST for issues and milestones, GraphQL for
sub-issue links, issue types, and Projects v2.

**What `github.py` must provide:**

```
fetch_managed_issues(repo, token) -> list[dict]
    Issues labelled gh-todo-sync, all states, with parent + issue type.
    Same shape sync_lib.build_actions already expects — do not change the shape.

fetch_project(owner, number, token) -> dict
    id, fields (with options and iteration configs), items keyed by issue number.

create_issue(repo, spec, token) -> int
edit_issue(repo, number, changes, token) -> None
set_issue_state(repo, number, closed, token) -> None
set_parent(repo, parent_number, child_number, token) -> None
add_to_project(project_id, issue_node_id, token) -> str
set_project_field(project_id, item_id, field, value, token) -> None
```

Keep the observed-issue dict shape identical to what `gh issue list --json`
produced. `sync_lib` consumes it and its tests assert on it. Changing the shape
means rewriting tested code for no gain.

**Rate limiting and retries.** A 200-item todo file is several hundred API
calls. Respect `X-RateLimit-Remaining`, back off on 403 secondary limits, retry
5xx with jitter. The skill never needed this because `gh` handled it.

**Ordering.** Parents before children, always. `sync_lib.build_actions` already
emits actions in that order; preserve it.

---

## 8. Tool and resource surface

### `plan`

```
todo:           str   (required)  markdown content, not a path
repo:           str   (required)  "owner/name"
project_number: int   (optional)
project_owner:  str   (optional)  defaults to repo owner
reconcile_drift: bool (default true, see Section 11)
token:          str   (optional)  overrides the server default
```

Returns:

```
plan_id:  str
summary:  {create, update, noop, orphan}
warnings: list[str]
markdown: str      rendered plan, from sync_lib.render_plan
actions:  list     structured, for clients that want to render their own
orphans:  list
```

Return **both** `markdown` and `actions`. Text-only clients need the first;
anything building UI needs the second.

### `apply`

```
plan_id: str (required)
token:   str (optional)
```

Returns `{created, updated, fields_set, skipped, issue_numbers, failures}`.

`failures` is a list, not an exception. A partial apply is a normal outcome:
report what succeeded, what did not, and why. The markers make re-planning after
a partial failure safe — that is what they are for.

### `validate`

```
todo: str (required)
```

Returns parse result and warnings without touching GitHub. No token, no network.
Cheap, and the right tool for a client checking a file before committing to
anything.

### Resources

- `todo-to-github://format` — `references/input-format.md`
- `todo-to-github://example` — `assets/example-todo.md`

Clients need the format spec to convert a user's file. Serving it as a resource
means it does not have to be duplicated in every tool description.

### Tool descriptions

The client's model decides when to call these based on the description alone,
with no SKILL.md alongside. Each description must carry: what it does, that
`plan` is read-only and `apply` writes, and that `apply` requires a `plan_id`
from a plan the user has seen. Section 12's warning about silent content loss
belongs in `plan`'s description, not just in documentation.

---

## 9. Bugs already found — keep them fixed

Four bugs surfaced during skill testing. Three were invisible to unit tests and
only appeared under a simulated round trip. Every one has a regression test in
the ported suite. **Do not let the port reintroduce them.**

1. **Numeric field never converges.** GitHub returns number fields as floats
   (`5.0`); the todo file supplies strings (`"5"`). String comparison reports a
   change forever. Fixed by `sync_lib.values_equal`. The API layer must not
   re-stringify field values on the way in.

2. **Unreadable parent loops.** When the parent field cannot be read, every child
   looks permanently changed while producing no command to fix it — a silent
   infinite no-op. Fixed by `compare_parent=False`. Direct API access should make
   parent always readable, so pass `compare_parent=True` — but keep the parameter
   and its tests.

3. **Silent content loss on free-form input.** A `## Heading` + `- bullet` file
   parses cleanly and produces one empty epic per heading, discarding every
   bullet. No error. This is the single most dangerous failure mode. Fixed by
   warnings for dropped bullets and childless epics. Those warnings must reach
   the caller — see Section 12.

4. **Orphan sort order.** Cosmetic; sorted by key rather than issue number.

---

## 10. Errors

MCP tool errors are read by a model, not a human. Make them actionable.

| Condition | Behaviour |
|---|---|
| Todo fails to parse | Return the `ParseError` message with its line number. Never a stack trace. |
| Bad or missing repo | Explicit error naming the parameter. Never guess. |
| Token missing or insufficient scope | Fail at startup where possible; otherwise name the missing scope. |
| Unknown / expired / used `plan_id` | Say which, and say to re-run `plan`. |
| Repo changed since plan | Refuse, explain, require a fresh plan. |
| Label or milestone does not exist | Fail before applying, listing the missing names. The skill fails partway through; the server should not. |
| Rate limited | Retry with backoff; surface only if exhausted. |

The label/milestone pre-check is an improvement over the skill, which discovers
the problem halfway through creating issues. Do it during `plan` and put the
result in `warnings`.

---

## 11. Defaults reconsidered for multi-caller use

Two behaviours were chosen for a single local user and are riskier when the
caller is not the person who wrote the todo file. Both are open decisions, not
settled:

**Drift reconciliation.** Currently defaults to on — the todo file wins, and an
issue edited in the browser is reset. On a shared server that silently reverts
someone else's work. Consider defaulting to off.

**Orphans.** Currently reported, never actioned. This is the conservative
choice and I would keep it. Do not add auto-close without an explicit opt-in
parameter, and do not make that parameter default true.

---

## 12. Warnings must be unmissable

Bug 3 caused total content loss with no error. The mitigation is warnings, which
only work if the caller sees them.

- `warnings` is a top-level field on `plan`'s result, never nested.
- When any warning matches "has no stories" or "bullet(s) in its description",
  the `markdown` output leads with the warning block, before the summary.
- `plan`'s tool description states that a free-form file may parse and produce
  almost nothing, and that item counts should be checked against the source.

A caller that ignores all three has been told three times.

---

## 13. Testing

**Ported suites must pass unmodified.** That is the acceptance gate for
Sections 2 and 9.

**New tests:**

- `github.py` request construction against a mocked transport — URLs, bodies,
  label/assignee deltas, GraphQL mutation shapes.
- `planstore.py` — TTL expiry, single use, unknown id, state-fingerprint
  mismatch.
- `server.py` tool contracts via an in-process FastMCP client — schemas,
  `apply` refusing a bogus `plan_id`, tokens absent from every result and error.

**Round-trip test — do not skip this.** The skill's four bugs were found by a
fake `gh` holding state in JSON, replaying plan → apply → plan. Build the
equivalent: a fake GitHub API. It must reproduce real API quirks, particularly
number fields returning as floats — that is exactly what the unit tests missed.

Assertions: second plan is entirely no-op; a single edit produces exactly one
update; a deleted item becomes an orphan and is not touched; partial failure
leaves a re-plannable state.

**What no fake can verify.** Every fake response is written from the same docs
the implementation is written from, so a fake agrees with your misreading rather
than catching it. One run against a throwaway repo with a real token is required
before this is considered working. This applies to the sub-issue GraphQL
mutation and Projects v2 field writes in particular.

---

## 14. Packaging

- stdio transport first. It is what local clients use and needs no auth story
  beyond an environment variable.
- Streamable HTTP behind a flag, same tool definitions.
- Publish to PyPI so `uvx todo-to-github-mcp` works.
- Ship a client config snippet in the README.
- Test with the MCP Inspector before any client integration.

---

## 15. Out of scope

- Creating labels and milestones. Pre-flight check and fail; do not create.
- Writing back to the todo file. One direction only.
- Converting free-form files. That is the calling model's job, informed by the
  format resource. The server parses and warns; it does not guess.
- Webhooks or scheduled sync. Every run is caller-initiated.
- Any auto-close of orphans by default.

---

## 16. Open decisions

Settle these before Phase 2; each one shapes code:

1. **Auth model** — A+B as recommended, or straight to OAuth. Blocks everything.
2. **Drift default** — on as today, or off for shared use.
3. **Orphans** — keep reported-only, or add opt-in auto-close.
4. **Multi-repo** — one todo file targeting one repo, as today, or per-epic repo
   targeting. Assume single-repo unless decided otherwise; it is a much larger
   change than it looks.
