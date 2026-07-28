# Pipeline Composition

The architectural half of `15-build-tooling-plugins.md`. The individual plugins moved to their own
directories: Build, Docker, Package, Release, and ContainerPSGenerator.

## The thin agent

```text
Build Agent
  receive job → resolve tools → execute plugins → stream logs → return artifacts
```

The agent contains no documentation logic, no package logic, and no language-specific build logic. It
resolves and runs plugins.

This is the same rule as "Automator owns orchestration, plugins own business logic", applied one
level down. It matters because a build agent is where that rule erodes first: adding "just a small
Docusaurus step" to the agent is always easier than making it a plugin, and after four such additions
the agent is the monolith the architecture exists to avoid.

**The test:** if a capability is useful to run by hand, it is a plugin. Everything the build agent
does is useful by hand.

## Daisy chaining

```text
repository.inspect
→ build.restore
→ build.test
→ container-ps-generator.generate
→ documentation.build
→ package.nuget
→ docker.build
→ release.github
→ notification.discord
```

This is a workflow, not a feature of any plugin. No plugin in that chain knows the others exist.

### What makes the chain work

Three properties, all from the contract:

- **Artifacts pass by reference**, so a step consumes the previous step's output without assuming a
  shared filesystem — which is what lets the chain span two agents.
- **Exit codes are uniform**, so a failure strategy can be written once instead of per step.
- **Declared idempotency** determines what may be retried. The chain above is safe to retry up to
  `package.nuget`, and not after — `package` and `release` are `conditional`, and `notification` is
  effectively non-idempotent because a person has already read the message.

### The retry boundary

Worth stating explicitly, because it is where a naive "retry the whole workflow" causes damage:

| Segment                          | Retryable                                                                   |
| -------------------------------- | --------------------------------------------------------------------------- |
| `inspect` through `docker.build` | Yes — all idempotent                                                        |
| `package`, `release`             | Only through their conditional-idempotency checks, which refuse on mismatch |
| `notification`                   | No — the message was already delivered                                      |

A workflow retried from the start after a failure at `release` must not re-send the notifications
that already fired. Resumption uses the recorded step outcomes rather than replaying from zero, which
is why `06-workflow-engine.md` requires an immutable execution snapshot.

## Composition belongs to the host

No plugin calls another plugin. A plugin that shells out to a second plugin has taken on
orchestration: it now needs retry policy, timeout handling, and log correlation, all of which the
Automator already has and none of which the plugin can do as well.

The one exception worth naming is a plugin that uses a **library** shared with another plugin. That
is code reuse, not composition, and it does not cross the process boundary.

## Open questions

1. Is `repository.inspect` a separate plugin or part of the build plugin's `detect`?
2. Do build agents differ from generic execution agents, or is "build agent" just an agent with build
   plugins cached?
