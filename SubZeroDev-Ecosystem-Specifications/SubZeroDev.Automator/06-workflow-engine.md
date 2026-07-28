# Workflow Engine

## Purpose

Compose plugin commands into repeatable, versioned automation.

## Workflow definition

A workflow contains:

- stable ID
- name
- semantic version
- description
- parameters
- variables
- steps
- dependencies
- outputs
- triggers
- permissions
- default execution policy

## Example

```yaml
id: project-bootstrap
version: 1.0.0

inputs:
  specification:
    type: file
    required: true

steps:
  - id: compile
    uses: subzerodev.requirements.compile
    with:
      specification: ${{ inputs.specification }}

  - id: create-project
    uses: subzerodev.github.create-project
    needs: [compile]
    with:
      project: ${{ steps.compile.outputs.project }}

  - id: notify
    uses: subzerodev.notifications.send
    needs: [create-project]
    with:
      message: "Project created."
```

## Step contract

Each step defines:

- ID
- command
- version constraint
- inputs
- output mappings
- dependencies
- condition
- timeout
- retry
- execution target
- continue-on-error
- compensation
- concurrency group

## Execution graph

Phase One may support sequential steps.

Phase Two supports DAG execution with parallel branches.

## Data mapping

Inputs may reference:

- workflow inputs
- variables
- previous outputs
- artifacts
- secrets
- environment
- execution metadata

Expressions must be constrained and deterministic. Avoid embedding arbitrary code.

## Failure policies

- fail workflow
- continue
- retry
- skip dependents
- run compensation
- wait for approval
- mark partial success

## Retries

Retry configuration:

- max attempts
- initial delay
- backoff
- max delay
- retryable error codes
- retryable exit codes
- jitter

Non-idempotent commands should not retry automatically unless explicitly configured.

## Compensation

A step may define a compensating command.

Compensation is best-effort and recorded separately.

## Approvals

Future step type:

- pause workflow
- request approval
- expire after timeout
- capture approver and comment
- continue or reject

## Versioning

Each execution references an immutable workflow version snapshot.

Editing a workflow creates a new version.

## Concurrency

Controls:

- workflow-wide maximum
- per-command maximum
- concurrency groups
- singleton execution
- agent capacity

## Resumability

A resumed workflow must use the original snapshot and completed outputs.

Resume behavior must be explicit for side-effecting steps.

## Workflow events

The catalogue lives in `07-execution-events-and-artifacts.md`, which owns every event Automator
publishes and the `<Product>.<Aggregate>.<PastTenseVerb>` naming convention.

An earlier draft listed workflow events here in bare `WorkflowSucceeded` form while `07` used dotted
namespaced names. Two conventions for one event set is how subscribers end up matching on the wrong
string; the catalogue is stated once.

## Compensation failure

Compensation is best-effort, which means it can fail. A workflow left partially compensated is the
one state an operator must be told about, because automatic recovery is no longer possible:
`Automator.Workflow.CompensationFailed` is published, the workflow is terminal, and the execution
record names which compensating steps succeeded and which did not.

Nothing retries compensation automatically. A compensating action that failed once may have partially
applied, and re-running it blind is how a rollback makes things worse.

## Retry safety

Retry policy keys on `errors[].retryable` from the plugin envelope and on exit code. Two rules the
contract requires and this engine enforces:

- Exit `2` is never retryable — a usage or validation error is deterministic.
- **A retry must confirm the previous attempt is dead before starting.** Container stop is
  asynchronous, so retrying a timeout without confirming termination can run two copies of a
  non-idempotent command concurrently.

Non-idempotent steps are never retried automatically. A step declared `conditional` is retried only
through the condition its manifest states.
