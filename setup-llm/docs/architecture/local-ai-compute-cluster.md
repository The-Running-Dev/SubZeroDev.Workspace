---
title: Local AI Compute Cluster
sidebar_position: 5
description: Phase T3 skeleton for the Local AI Compute Cluster MVP.
---

## Local AI Compute Cluster (T3 Skeleton)

This document records the initial project skeleton introduced for Issue #16.

## Scope of This Slice

This T3 slice provides:

- `setup-llm/ai-cluster/compose.yaml` with dedicated `headless`, `ui`, `cloud`, and `intel-sycl-linux` profiles.
- Environment and route scaffolding:
  - `setup-llm/ai-cluster/.env.example`
  - `setup-llm/ai-cluster/config/litellm.yaml`
  - `setup-llm/ai-cluster/config/model-manifest.example.yaml`
- Lifecycle and validation script placeholders under `setup-llm/ai-cluster/scripts/`.
- Test placeholders under `setup-llm/ai-cluster/tests/`.

## Design Constraints Preserved

- Existing GitHub MCP Compose workflow remains under `setup-llm/docker/docker-compose.yml` and is not modified by this slice.
- No model binaries, API keys, or cloud credentials are committed.
- Compose topology is separated into `setup-llm/ai-cluster/` to isolate AI-cluster iteration from workstation setup integrations.

## Validation Command

Run from repository root:

```powershell
pwsh -File setup-llm/ai-cluster/scripts/Test-AiCluster.ps1
```

This currently validates static structure and optionally runs `docker compose config` when Docker is available.

## Next Steps

- T4: implement host-native `llama-server` process management.
- T5: replace mock backend wiring with production LiteLLM route/health behavior.
- T6+: complete embeddings, fallback policy, and CI contract tests.
