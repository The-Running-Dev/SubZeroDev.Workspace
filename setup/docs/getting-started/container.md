---
title: Container Quick Start
sidebar_position: 2
description: Run the setup and documentation without installing PowerShell on the host.
---

# Container Quick Start

The LLM Workspace Toolkit container includes PowerShell, the setup scripts, and the statically built documentation. The only host prerequisite is Docker.

## Serve the Documentation

```bash
docker run --rm --name llms-docs \
  -p 8080:8080 \
  ghcr.io/the-running-dev/llms:latest
```

Open [http://localhost:8080](http://localhost:8080). The default `docs` command runs nginx in the foreground and serves the documentation embedded at image-build time.

## Run the Setup

Use the `setup` command to pass arguments to `setup/setup.ps1` inside the Linux container:

```bash
docker run --rm -it \
  ghcr.io/the-running-dev/llms:latest \
  setup -Client Codex -SkipGitHub
```

This removes the host PowerShell requirement, but setup remains container-scoped. It installs and registers tools inside that container. Persist configuration and working files with named volumes or bind mounts:

```bash
docker volume create llms-config

docker run --rm -it \
  -v llms-config:/root/.config \
  -v "$PWD:/workspace" \
  ghcr.io/the-running-dev/llms:latest \
  setup -Client Codex -SkipGitHub
```

## Enable Docker-Based Integrations

GitHub MCP launches another container, so it requires access to the host Docker engine. Mount the Docker socket and the git-ignored token file when you deliberately want that access:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/setup/docker/.env:/opt/llms/setup/docker/.env:ro" \
  -v llms-config:/root/.config \
  ghcr.io/the-running-dev/llms:latest \
  setup -Client Codex
```

Mounting the Docker socket gives the container control of the host Docker daemon. Only run trusted images and scripts with this mount. Docker Desktop users may need to enable Docker-socket sharing for Linux containers.

## Open PowerShell

The image uses PowerShell as its Docker entry point. Start an interactive shell with:

```bash
docker run --rm -it ghcr.io/the-running-dev/llms:latest pwsh
```

The scripts are available under `/opt/llms/setup`, and `/workspace` is reserved for mounted projects.

## Build Locally

Initialize the documentation submodule before building:

```bash
git submodule update --init --recursive
docker build -t llms-toolkit .
docker run --rm -p 8080:8080 llms-toolkit
```

Pull requests build the Dockerfile and upload an OCI image archive as a workflow artifact. Builds from `main` additionally publish `ghcr.io/the-running-dev/llms:latest` and an immutable commit-SHA tag to GitHub Container Registry.
