# SubZeroDev Automator

The orchestration product: it runs plugins on a schedule or on demand, composes them into workflows,
records what happened, and exposes the result over REST and MCP.

The Automator sits on Platform and orchestrates plugins. It knows the plugin contract's vocabulary —
commands, envelopes, exit codes, artifacts — and nothing about any plugin's domain.

## Contents

| Document                                | Covers                                                  |
| --------------------------------------- | ------------------------------------------------------- |
| `03-automator-specification.md`         | Purpose, scope, and the execution model                 |
| `05-runtime-hosts.md`                   | How each runtime type is executed and what it enforces  |
| `06-workflow-engine.md`                 | Steps, conditions, and composition                      |
| `07-execution-events-and-artifacts.md`  | The execution event catalogue and artifact registration |
| `08-clients.md`                         | The Automator's own CLI and PowerShell modules          |
| `09-rest-and-mcp.md`                    | The REST API and the brokered MCP surface               |
| `10-security-model.md`                  | Capability enforcement, secrets, trust levels           |
| `11-operations.md`                      | What an operator does with a running system             |
| `project-bootstrap.workflow.yaml`       | A worked workflow example                               |
| `adr/ADR-001-out-of-process-default.md` | Plugins execute out of process, with no exception       |

## Plugins run without it

The Automator is an integration layer over the plugin contract, never a prerequisite for it. Every
plugin is fully usable from a terminal with no host present, with the same commands and the same
envelope on stdout.

The Automator adds scheduling, history, approvals, and credential brokering _around_ a run. It does
not become part of what a run needs to succeed — which constrains its design, deliberately. See
ADR-002 in `SubZeroDev.PluginContract`.

## Execution model

Plugins execute **out of process**, always. The Automator never loads independently versioned plugin
code into the control-plane process — not for first-party plugins, not for signed ones. Signing says
who published something, not whether its dependency graph is safe to load into the control plane.

Capability enforcement varies by runtime host: only Docker enforces the declared capability model,
and process-based hosts enforce nothing. Both facts are reported to the operator, because a
declaration that one host enforces and another merely records is a real difference.

## Where the other halves went

Events and notifications, observability primitives, and tenancy/billing/licensing live in the
Platform repository. This repository keeps what is about _running things_.

## Status

Specification only. The Automator MVP is Phase 4 — deliberately after two plugins exist, because a
contract validated by one implementation is a contract fitted to that implementation, and an
orchestrator has nothing to orchestrate until two things exist.
