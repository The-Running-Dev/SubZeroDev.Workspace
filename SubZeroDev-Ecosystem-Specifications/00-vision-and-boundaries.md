# Vision and System Boundaries

## Vision

SubZeroDev is evolving from a collection of independent tools into a coherent software platform.

The recurring pattern across the existing projects is:

- each tool has configuration
- each tool has logging
- each tool needs documentation
- each tool may need PowerShell access
- each tool may be containerized
- each tool may be invoked locally, remotely, manually, through an API, or through AI tooling
- tools may need to be chained into workflows
- tools produce artifacts
- tools need notifications, diagnostics, versioning, releases, and operational visibility

The ecosystem exists to implement these concerns once and reuse them consistently.

## Core products

### SubZeroDev.Platform

A reusable application framework comparable in purpose to ABP Framework.

It supplies cross-cutting infrastructure:

- hosting
- configuration
- identity
- authorization
- organizations and tenancy
- billing and subscriptions
- licensing
- notifications
- storage
- events
- background jobs
- scheduling abstractions
- plugin abstractions
- API conventions
- MCP conventions
- observability
- shared UI and administration capabilities
- testing infrastructure

Platform is not an automation product.

### SubZeroDev.Automator

An automation and orchestration product built on Platform.

It supplies:

- plugin registry
- plugin installation and resolution
- runtime host selection
- command execution
- workflows
- scheduling
- job queues
- execution history
- artifacts
- events
- notifications
- remote agents
- REST and MCP exposure
- PowerShell and CLI clients
- web-based administration

Automator remains thin. It does not implement GitHub logic, documentation generation, builds, package publishing, requirements analysis, or other domain behavior.

### Plugins

Plugins are independently useful capabilities.

A plugin must be runnable manually without Automator wherever practical.

Examples:

- GitHub metadata collector
- Requirements compiler
- documentation builder
- ContainerPSGenerator
- build tool
- package publisher
- GitHub release tool
- Docker tool
- notification provider
- AI analysis tool
- WinGet tool
- QNAP package builder

A plugin can later be installed into Automator without rewriting its business logic.

## Non-goals

The ecosystem is not intended to become:

- a monolith containing every tool
- a replacement for programming languages
- a mandatory cloud service
- a Docker-only system
- a workflow engine embedded in every plugin
- a universal framework for arbitrary external users from day one
- a marketplace before the local product works
- a Kubernetes-first platform
- a generic low-code application builder

## Product deployment modes

The architecture must support:

1. Local developer execution
2. Homelab deployment
3. Single-server self-hosted deployment
4. Multiple execution agents
5. Hybrid hosted control plane with customer-hosted agents
6. Future managed SaaS

The same plugin contract should survive all deployment modes.
