# ADR-001: Separate Platform from Automator

## Status

Accepted

## Context

Two kinds of concern were being specified together.

One kind is reusable and has nothing to do with automation: hosting, identity, configuration,
persistence, observability, notifications, billing. The other is what the product actually does:
plugin execution, workflows, agents, schedules, execution history.

Building them as one thing is faster at first and expensive later, because the reusable half acquires
automation-shaped assumptions — a storage abstraction that knows about execution records, a
notification service whose only caller is a workflow step — and by the time a second product wants
it, extraction means untangling rather than referencing.

The draft recorded the split as an intention with no boundary rule and no scope. Both matter more
than the split itself: the failure mode of a platform layer is not that it fails to exist, it is that
it grows two dozen speculative packages before anything consumes them.

## Decision

**Two products. `SubZeroDev.Platform` carries reusable infrastructure; `SubZeroDev.Automator` carries
automation. Automator depends on Platform. Platform never depends on Automator, and never on a
plugin.**

The dependency direction is the whole content of the decision, and it is checkable: a reference from
Platform to Automator is a build failure, not a review comment.

Two rules bound it.

**The boundary test.** A concern belongs in Platform when a non-automation product would want it
unchanged. Execution records, plugin manifests, workflow state, and agent registration fail that test
however infrastructural they look — they are automation concepts wearing infrastructure clothes.

**The extraction guard.** A candidate becomes a Platform package when a _second_ consumer needs it,
not when the first one does. Until then it lives inside Automator, where it is cheap to move. Platform
therefore starts minimal — Abstractions, Core, Hosting, Persistence, Observability, Testing — with
the rest deferred to W6 and admitted only against a real second consumer.

The guard exists because the original draft specified twenty-four Platform packages before a single
one had a consumer. Without it, the minimal six becomes those twenty-four by increments, each
addition individually reasonable.

## Consequences

- Reusable infrastructure stays free of automation assumptions, which is the point.
- More repositories and packages, and version coordination between them. Accepted: it is the cost of
  the boundary being enforced by the build rather than by intent.
- Platform's public API becomes a commitment earlier than Automator's internals would have, so a
  premature promotion is expensive to walk back. The extraction guard is what keeps that rare.
- The plugin contract lives in neither, because it depends on nothing and both depend on it. That is
  why it gets its own repository rather than a corner of Platform.
- Platform can be evaluated on its own terms — a package nobody outside Automator would want is
  visibly in the wrong place.

## Alternatives considered

**One product, extract later.** Fastest to start. Rejected: "later" arrives after the reusable half
has absorbed automation assumptions, at which point extraction is a rewrite. The dependency rule
costs almost nothing to hold from the beginning and cannot be retrofitted cheaply.

**Full Platform up front, as the original draft specified.** Twenty-four packages covering every
anticipated concern. Rejected: packages designed without a consumer encode a guess about how they
will be used, and the guess is usually wrong in a way that is only discovered once the API is public.

**Platform as a shared internal library rather than a product.** Lighter, no independent versioning.
Rejected: it makes the boundary a convention, and a convention that is not enforced by the build is
one that erodes silently.
