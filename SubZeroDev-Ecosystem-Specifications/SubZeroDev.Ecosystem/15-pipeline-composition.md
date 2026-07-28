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
build.detect
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

The first step was written as `repository.inspect` when the chain was drafted, and the decision below
resolved it to the build plugin's `detect`. The example now says so, rather than naming a plugin ID
that was decided against — an ID in an example is the first place someone looks for the plugin.

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

## Decisions on previously open points

**`repository.inspect` is the build plugin's `detect`.** A separate plugin whose only job is to look
at a repository and report what it is would duplicate the adapter detection the build plugin needs
anyway, and the two would drift on what counts as a Node project.

**This decision constrains the Project Setup plugin**, which also reads a directory to infer topics.
That inference is incidental to provisioning rather than its purpose, so it does not make a second
inspection plugin — but it is the same detection, and two implementations would drift on exactly the
question this decision names. Project Setup consumes the build plugin's detection rather than
reimplementing it, on the same reasoning that gives the Node plugins one shared GitHub client.

Until the build plugin exists, Project Setup carries its own minimal detection and is the first
consumer that will force the extraction. That is stated so it is a known debt rather than a
rediscovery.

**A build agent is a generic agent with build plugins cached** and appropriate labels. A distinct
agent type would mean a second scheduling path, a second health model, and a second set of selection
rules, for no capability the label does not already express.
