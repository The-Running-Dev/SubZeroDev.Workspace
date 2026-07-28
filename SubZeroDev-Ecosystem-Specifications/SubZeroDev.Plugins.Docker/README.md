# SubZeroDev Docker Plugin

Builds, tags, pushes, inspects, and scans container images as a plugin command rather than as
build-agent logic.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.docker`                      |
| CLI       | `subzerodev-docker`, alias `sz-docker`   |
| Status    | **Sketch** — blocked on a trust question |

## Contents

| Document              | Covers                                                    |
| --------------------- | --------------------------------------------------------- |
| `15-docker-plugin.md` | Purpose, the architectural tension, and the open question |

## The unresolved part

This plugin needs Docker access, and the ecosystem's security model treats Docker access as the
capability you least want to grant. Access to the Docker socket is access to the host — it can start
a privileged container, mount the host filesystem, and read other containers' secrets.

The plugin that _is_ Docker cannot be sandboxed by the runtime that sandboxes every other plugin. So
the open question is not how to declare the capability, but what trust level a plugin holding it must
have, and what an operator is actually agreeing to when they grant it.

Until that is answered, this specification stays a sketch.

## Status

Sketch, Phase 5 or later. Nothing here should be implemented before the trust question is settled and
the security model says how an operator grants host-level access.
