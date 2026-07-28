# Working in Platform

Platform is the reusable application framework: hosting, configuration, persistence, observability,
events and notifications, tenancy, billing, licensing. It is infrastructure that a product other than
the Automator would want unchanged.

## The rule that defines this repository

**Platform never depends on Automator, and never on a plugin.** This is a build failure, not a review
comment. Everything else here follows from it.

The failure mode is not that the dependency gets declared — nobody would do that — it is that a
Platform abstraction quietly acquires an automation shape. A storage interface that knows what an
execution record is. A notification service whose only conceivable caller is a workflow step. An
event envelope with a field that only means something to a scheduler. By the time a second product
wants the package, using it means untangling rather than referencing.

**The test for anything in this repository:** would a product that has nothing to do with automation
want this, unchanged? If it needs one automation-shaped concept to make sense, it belongs in the
Automator.

Concepts that fail the test however infrastructural they look: execution records, plugin manifests,
workflow state, agent registration, run history, schedules.

## The extraction guard

**A capability becomes a Platform package when a _second_ consumer needs it, not when the first one
does.** Until then it lives inside the Automator, where it is cheap to change.

The original draft specified twenty-four Platform packages before a single one had a consumer. A
package designed without a consumer encodes a guess about how it will be used, and the guess is
usually wrong in a way discovered only after the API is public.

Platform therefore starts minimal — Abstractions, Core, Hosting, Persistence, Observability,
Testing — and the rest is deferred to work package W6, admitted only against a real second consumer.

Adding a seventh package is a decision, not a refactor. It needs the second consumer named.

## What is here and what moved

Three of these documents were split from larger ones, and the halves that left are the ones people
look for here first:

| Here                              | The half that went to the Automator                      |
| --------------------------------- | -------------------------------------------------------- |
| `07-events-and-notifications.md`  | Execution events and artifacts                           |
| `11-observability.md`             | Operations — what an operator does with a running system |
| `10-tenancy-billing-licensing.md` | The security model, because enforcement is Automator's   |

Observability is the primitives; operations is their use. Events is the envelope, bus, outbox, and
channels; the execution event catalogue is Automator's because those events are about executions.

## A caution on the name

`SubZeroDev.Platform` keeps a category word as a product name. That was decided knowingly — see
ADR-002 in the Architecture repository — with the cost accepted as occasional conversational
ambiguity. Inside this repository "Platform" is unqualified; everywhere else it appears with its
root. Do not reopen the naming; do preserve that usage.

## Before you finish

- Check that nothing you added names an automation concept.
- If you added a package, name the second consumer in the commit message. If you cannot, it belongs
  in the Automator for now.

## Conventions

These hold in every SubZeroDev specification repository. The canonical copy of this block is
`AGENTS.md` in the Architecture repository; it is repeated here because a repository has to stand on
its own.

- **Reference, never restate.** A rule that lives in another document is linked, not copied. Two
  copies of a rule is a promise they will diverge and a guarantee nobody will notice which is stale.
- **The plugin contract outranks plugin specifications.** Where a plugin document and the contract
  disagree, the contract is correct and the plugin document has drifted. See ADR-003 in
  `SubZeroDev.PluginContract`.
- **A decision gets an ADR.** Status is exactly one of `Proposed`, `Accepted`, `Superseded`, or
  `Deprecated`, under a `## Status` heading. An accepted ADR states its context, the decision, the
  consequences _including the costs_, and the alternatives it rejected and why. "Accepted in existing
  practice" is not a status — ratifying current practice is a note in the context.
- **Move, never copy.** A specification has exactly one home. Where another repository needs the
  text, it references a tagged commit rather than duplicating the file.
- **Give reasons.** These documents are read by people deciding what to build. An assertion with no
  reason cannot be evaluated, and cannot be safely revised by someone who was not there when it was
  written.
- **Markdown is Prettier-formatted**, 100 columns, LF endings.
