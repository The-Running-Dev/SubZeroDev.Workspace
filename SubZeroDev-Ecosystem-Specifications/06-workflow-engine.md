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

- WorkflowCreated
- WorkflowQueued
- WorkflowStarted
- StepQueued
- StepStarted
- StepSucceeded
- StepFailed
- WorkflowSucceeded
- WorkflowFailed
- WorkflowCancelled
- WorkflowPaused
- WorkflowResumed
