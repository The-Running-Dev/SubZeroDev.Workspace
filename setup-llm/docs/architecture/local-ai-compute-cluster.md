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
- Local runtime config template:
  - `setup-llm/ai-cluster/config/local-inference.example.json`
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

### Local Inference Lifecycle (T4)

Copy the template and fill in executable/model paths:

```powershell
Copy-Item setup-llm/ai-cluster/config/local-inference.example.json setup-llm/ai-cluster/config/local-inference.json
```

Set the backend key in your shell and start providers:

```powershell
$env:LOCAL_INFERENCE_API_KEY = 'replace-me-before-use'
pwsh -File setup-llm/ai-cluster/scripts/Start-LocalInference.ps1
pwsh -File setup-llm/ai-cluster/scripts/Get-LocalInferenceStatus.ps1
pwsh -File setup-llm/ai-cluster/scripts/Stop-LocalInference.ps1
```

The start script validates model paths, optional model hashes, API key presence, and writes PID/log state under `setup-llm/ai-cluster/state` and `setup-llm/ai-cluster/logs`.

## Next Steps

- T4: implement host-native `llama-server` process management.
- T5: replace mock backend wiring with production LiteLLM route/health behavior.
- T6+: complete embeddings, fallback policy, and CI contract tests.
