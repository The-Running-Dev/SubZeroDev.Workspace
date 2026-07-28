# Documentation Plugin

## Existing architectural insight

The existing Docusaurus template repository builds and publishes a reusable Docker image.

Project documentation can use:

```dockerfile
FROM ghcr.io/the-running-dev/docs-template:<version>

COPY ./docs /app/docs
COPY ./README.md /app/README.md
```

This makes the image an extensible documentation capability.

## Purpose

Provide standardized documentation build, preview, validation, and packaging.

## Commands

```text
sz-docs build
sz-docs serve
sz-docs validate
sz-docs package
```

## Inputs

- Markdown docs
- README
- site configuration
- static assets
- optional OpenAPI
- optional generated PowerShell docs
- optional generated architecture diagrams

## Outputs

- static site
- validation report
- broken-link report
- packaged site artifact
- Docker image, optional

## Responsibilities

Base image owns:

- Node version
- Docusaurus version
- plugins
- theme
- build scripts
- search configuration
- common assets
- production defaults

Project owns:

- content
- project metadata
- site-specific navigation
- custom overrides
- domain configuration

## Extensibility

A downstream Dockerfile can add or replace content without cloning the template repository.

The documentation image is both:

- a reusable base
- a manually executable tool
- a future Automator plugin implementation
