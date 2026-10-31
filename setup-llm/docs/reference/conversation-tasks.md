# VS Code conversation tasks (opt-in)

Use **Tasks: Run Task → Conversation: Fork / Attach / Return / Review memory
(Opt-in)**. Nothing runs on folder open or through provisioning dependencies.
The existing setup, preview, MCP and doctor tasks retain their definitions.

Requires Node **22.18 or later**, Git for the selected memory project's origin,
and an already installed AgentKit with the conversation helpers from #498–#500.
Resolve the kit through `AGENTKIT_HOME`, otherwise `.agent-kit` under `HOME` /
`USERPROFILE` (then the OS home). A broken explicit kit override fails; it never
installs, updates or silently selects a different kit. No extension command is
assumed. The wrapper adds no npm package or runtime dependency.

## Select private inputs

Each invocation asks for an existing private archive checkout and an existing,
reviewed UTF-8 JSON request, both with **no default**. Memory tasks also ask for
the existing project checkout whose origin selects the namespace. Choose absolute
paths without surrounding quotes; spaces, Unicode and shell metacharacters are
literal process arguments. Inputs are masked and task command echo is disabled. Private selections travel
through the task environment, so they are absent even from editor command/exit
messages; the wrapper passes them to AgentKit as literal process arguments.

Prepare source selections and requests using the installed
[conversation skill](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/blob/main/skills/conversation/SKILL.md).
That is the authority for fields, byte spans, attribution, revisions and retry IDs.
The selected archive must already follow its Notes conventions; review its local
instructions first. Relative source paths resolve from the Workspace root (the
task working directory), **not** the request directory. Prefer absolute source
paths for durable retries. The task refuses a request/archive inside this public
checkout, including symlink/junction targets. This guard does not certify privacy
of other paths or remotes. Use user-only private storage outside all public
checkouts; on Windows retain user-only directory ACLs.

| Entry point | Request action | Result / next step |
| --- | --- | --- |
| Fork | `fork` | Preserve selected source and attributed handoff in the chosen archive. |
| Attach | `attach` | Append the explicitly selected later source/statement at the expected revision. |
| Return | `return` | Render selected outcomes; manually navigate to the saved parent and copy them. |
| Review memory | `propose` | Review individual candidates privately; no store/configuration is needed. |
| Store selected memory candidates | `store` | Separate request with explicitly selected proposal IDs; never automatic acceptance. |
| Native host outbox | `prepare`, `dispatch`, `record`, `reconcile` | Delegate capability selection and recovery to the installed host helper; no native transport in Workspace. |

Review does not run a `store` request. Selection does not accept a candidate.
Acceptance stays a separate explicit `/memory show|accept` operation in the
[memory skill](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/blob/main/skills/memory/SKILL.md).
Do not put transcripts, raw prompts or unselected personal material into memory.
`NotConfigured` exits 2; it does not enable memory or create configuration.

The tasks take memory configuration only from AgentKit's existing configuration
and environment. The wrapper CLI can pass `--namespace` only for a destination the
user explicitly named; the editor tasks do not infer one or prompt for a default.

## Read results privately

Each attempt reserves a new `.conversation-result-<random>` directory **beside the
selected private request** before running a helper. It retains helper stdout as
`result.json` and any stderr as `stderr.txt`; portable/host responses also produce
`packet.md` with the unchanged AgentKit packet and canonical note/manifest/receipt
links. Open the Markdown preview for parent navigation. Archived-source relative
links in the packet are relative to the canonical **Note**, so follow that link
for sources. A parent ID or URI is a saved reference, not proof navigation works.

The terminal prints status, exit code and the random result directory name only;
source bodies, proposals, helper diagnostics and personal paths stay private.
Result directories are private scratch, not another archive/store or Git input.
POSIX files use mode 600 in a mode 700 directory; Windows inherits the selected
directory's ACLs. Keep result files and requests out of public commits and logs.

The canonical helper still owns receipts, locks and partial writes. Results such
as `WrittenUncommitted` confirm local files, not a commit/push. Follow the archive's
existing private Git workflow separately; the tasks never run Git against it.
Retain exact requests and operation/review IDs for retries. A process failure or
unparseable result may follow writes: inspect private diagnostics and canonical
receipts before retrying. Never refresh revisions, delete locks/receipts or invent
a new identity to hide uncertainty. Replayed revisions can describe an original
receipt rather than the branch's current revision.
New memory writes are candidates; a replay can return a memory accepted elsewhere.
Storage itself never accepts one. Inspect the private per-item current state.

## Native capability selection

Use the [capability report](conversation-capabilities.md) and current session tool
contracts, then prepare a separate private request through AgentKit's
[native host workflow](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/blob/main/skills/conversation/references/native-host.md).
Its `capabilities` can use the report's `agentKitHost` projection after rechecking
the current host. The report is evidence, never authorization. Explicit creation,
full-history and navigation authorizations remain AgentKit's rules.

The outbox task returns private tool-call data only. A supported host/skill must
invoke the exact released `Call` once and record the observed result. The task
does not claim a native operation ran. If capabilities are absent or unknown,
AgentKit preserves the portable packet and manual return. No messaging, extension
API invention, graph ingestion, automatic configuration or new store is added.

## Windows editor walkthrough

**Status: documented, not run in the implementation's Linux environment.** The
automated suite executes resolved committed task arguments through Node; it does
not exercise VS Code's input UI, terminal rendering or Windows editor navigation.

1. Start from a clean supported checkout, Node >=22.18, Git, PowerShell and an
   installed AgentKit containing #498–#500. Verify `git status --short --branch`.
   Close all VS Code processes so a newly launched editor receives the environment
   below. Keep the existing value of `AGENTKIT_MEMORYKIT_CONFIG` for restoration.
2. From PowerShell in the checkout, prepare **synthetic-only** private fixtures:

   ```powershell
   $priorMemoryConfig = $env:AGENTKIT_MEMORYKIT_CONFIG
   $f = node setup-llm/tests/conversation-task-fixture.mjs --directory $env:TEMP | ConvertFrom-Json
   $env:AGENTKIT_MEMORYKIT_CONFIG = $f.absentConfig
   code --new-window .
   ```

   The fixture directory contains `fixture.json` with the exact selections. It
   creates only a local synthetic project origin and a JSON test adapter, not a
   real MemoryKit installation. It makes no network request or configuration
   change to an existing installation. Keep fixture paths/results private.
3. Through **Tasks: Run Task**, run Fork, Attach, then Return. Select `archive`
   from `fixture.json` and the corresponding `requests.fork`, `.attach`, `.return`
   file each time. Check `Forked` revision 1, `Attached` revision 2, then `Returned`
   / `ReadOnly` in private `result.json`. Open `packet.md` in preview, follow the
   canonical Note link, confirm the parent reference and selected later outcome.
   The synthetic parent is deliberately not a live chat; do not claim it opened.
   Compare archived source bytes/hashes with the two supplied fixture files.
4. Run Review memory with `requests.review`, the same archive and `project` from
   the fixture. Inspect the private review and its two attributed proposals.
   Run Store selected memory candidates with `requests.store`: expect
   `NotConfigured` / exit 2, no absent config file and no synthetic store writes.
5. Close the editor again. In the launching PowerShell set
   `$env:AGENTKIT_MEMORYKIT_CONFIG = $f.config`, then `code --new-window .`.
   This explicitly selects **only the synthetic adapter for this test process**.
   Run the same Store task/request. Inspect the single selected `decision` result:
   candidate, unverified, source attribution retained; `summary` is not stored.
   Rerun it and confirm the same operation identity and one record. Do not accept
   anything; acceptance is a separate user action, deliberately unsupported by
   this test adapter. Confirm no real memory configuration was created/modified.
6. Run Native host outbox with `requests.host`: expect `unsupported`, `Call: null`
   and the preserved selected packet. With a real supported host, use its canonical
   prepare/dispatch/record workflow separately and record actual observations.
7. Run the existing **Workstation Setup (Preview)** and **MCP: Doctor Workspace
   Profiles** tasks. Record prerequisite/doctor failures honestly; do not run
   installing setup or MCP registration merely to test this change. Confirm those
   tasks remain selectable, use their existing definitions and do not invoke a
   conversation task. Verify task terminals contain no private inputs or bodies.
8. Record Windows/Node/VS Code/AgentKit versions, each task's observed state,
   parent/link behavior and any failed/skipped step. Close the test editor and
   restore `$env:AGENTKIT_MEMORYKIT_CONFIG = $priorMemoryConfig` in PowerShell.
   Fixture cleanup is manual after inspecting results; never commit private files.

## Automated validation

With an existing kit selected, from the checkout:

```powershell
node --test setup-llm/tests/conversation-tasks.test.mjs
```

Set `AGENTKIT_HOME` in the launching environment to include integration coverage;
otherwise the installed-kit test is explicitly skipped. The CI workflow pins the
merged upstream contract and runs Node 22.18 and 24 on Windows, Linux and macOS.
It exercises process entry points with spaces, Unicode and shell metacharacters,
privacy, action mismatch/refusal, source preservation, replay/revision conflict,
memory off/configured test adapter, candidate-only storage, unsupported native
fallback and supported synthetic outbox dispatch. CI is not a Windows editor
walkthrough or a live MemoryKit/native-host smoke test.
