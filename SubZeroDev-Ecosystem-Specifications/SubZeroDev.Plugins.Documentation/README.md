# SubZeroDev Documentation Plugin

Builds and publishes project documentation from a shared Docusaurus base image.

## Contents

| Path                                            | Covers                                            |
| ----------------------------------------------- | ------------------------------------------------- |
| `14-documentation-plugin.md`                    | Purpose, commands, inputs, outputs, extensibility |
| `adr/ADR-001-docker-documentation-extension.md` | Why extensibility is image inheritance            |

## How extension works

A shared base image carries the theme, navigation shell, build pipeline, and search configuration. A
project's documentation image derives `FROM` that base and adds its own content and configuration
overrides — nothing else.

Tooling is centralized, so a theme or pipeline change is made once. A project repository carries only
its own delta, which is the part worth reviewing. Local preview and CI deployment use the same image,
so "works locally" means something.

The base is pinned by **digest**, not by tag, so a base rebuild cannot silently change a derived
project's output.

The cost, accepted: a project cannot upgrade independently of what the base offers. Divergence is
what this pattern is chosen to avoid.

## Status

The image inheritance pattern is in use today and is ratified rather than proposed. What remains is
aligning the plugin to the plugin contract — manifest, commands, envelope, conformance. The
specification is thinner than the GitHub and Backlog ones and has not had the same editing pass.
