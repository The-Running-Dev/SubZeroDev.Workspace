# ADR-002: Define a Plugin as a Capability

## Status

Proposed

## Decision

A plugin is a capability defined by a manifest and command contract.

It is not synonymous with a Docker image.

Supported implementations may include Docker, .NET, Node.js, Python, PowerShell, executable processes, and remote APIs.

## Consequences

Automator requires runtime hosts.

The plugin contract must be language-neutral.

Docker remains a preferred isolation and distribution mechanism.
