# ADR-005: Use Docker Image Inheritance for Documentation Extensibility

## Status

Accepted in existing practice

## Context

The shared Docusaurus template builds a reusable image.

Project documentation can derive from the image and overlay project-specific content.

## Decision

Retain this pattern as the documentation plugin's primary container implementation.

## Consequences

- centralized tooling
- project-specific delta only
- easy local preview and CI deployment
- base image versioning must be managed carefully
