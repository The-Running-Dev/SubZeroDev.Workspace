---
title: Local Inference with Ollama and Gemma 4
sidebar_position: 8
description: Ollama as a host-native backend behind the existing LiteLLM gateway, the Phase 1 runtime check, and what is still open.
---

## Local Inference with Ollama and Gemma 4

Ollama serving Gemma 4 is a second host-native backend for the Local AI Compute Cluster. It sits behind the same loopback LiteLLM gateway as the llama.cpp SYCL backend from [ADR 0001](../decisions/0001-ai-cluster-mvp-architecture.md), so clients keep calling logical aliases and never an Ollama model name.

The first target is an Intel Arc B580 workstation (12 GB VRAM, 128 GB RAM). Dual RTX 3090 is later work.

## Why behind the gateway, not instead of it

The gateway already provides the things a provider interface needs:

- stable aliases
- bearer-key auth on loopback
- no silent cloud fallback
- redacted diagnostics
- deterministic contract tests

Ollama is added by changing which model id an alias sends, not by adding a client path. The reasoning and the rejected alternatives are in `design/90-decisions.md` (2026-10-08 entry).

## Switching a route to Ollama

Every local route reads its model id from the environment (`LOCAL_*_MODEL`) as well as its base URL. The defaults keep the llama.cpp names, so nothing changes until `.env` says so. The commented *Ollama + Gemma 4 profile* block in `setup-llm/ai-cluster/.env.example` is the switch:

- `coding`, `general`, `vision` and `multimodal` go to `gemma4:12b`
- `fast` goes to `gemma4:e4b`

`embeddings` stays on its own backend; Gemma 4 is not an embeddings model.

Ollama's OpenAI-compatible endpoint routes on the model id. llama-server ignores it. That is why the id moved into the environment rather than into a second set of routes.

Never set a route to an Ollama cloud tag (`:cloud`, `-cloud`). Those run off this machine. `tests/routing.Tests.ps1` fails if one appears in the versioned config.

## Phase 1: prove it runs locally

Install Ollama and pull the model yourself; nothing in this repository downloads models:

```powershell
winget install Ollama.Ollama
ollama pull gemma4:12b
```

Leave `OLLAMA_HOST` unset (Ollama then listens on `127.0.0.1:11434`). Ollama has no authentication.

Then run the runtime check on the machine with the GPU:

```powershell
pwsh -File setup-llm/ai-cluster/scripts/Test-OllamaRuntime.ps1 -Force
pwsh -File setup-llm/ai-cluster/scripts/Test-OllamaRuntime.ps1 -Force -Model gemma4:e4b
```

It fails when:

- the URL or the listening socket is not loopback
- Ollama is unreachable
- the model is not pulled (it prints the `ollama pull` command and never pulls)
- the model is a cloud model

It then streams a fixed prompt a few times and records:

- time to first token, measured by the client
- prompt and generation tokens per second, load time and total time, from Ollama's own counters
- how much of the model sits in GPU memory (`/api/ps`)

A model that is not fully in GPU memory is a warning that says *GPU acceleration not verified*. It is never reported as a pass.

The result is written as JSON under `setup-llm/ai-cluster/state/`, which is gitignored. It holds a hash of the prompt and the response length, never the prompt or the response text. `Test-HardwareSmoke.ps1`, and therefore `doctor-ai-cluster.ps1 -RunHardwareSmoke`, now runs this check instead of being a placeholder. Both still skip in standard CI.

The check does not prove Vulkan specifically. It records Ollama's version, the host GPUs and the GPU memory share. Which Ollama backend served the model is in Ollama's own server log.

Copy measured values into `config/model-manifest.example.yaml` (or a local manifest) only from a real result file on the target host.

## Status against the plan

| Phase | State |
| --- | --- |
| 1. Local proof (runs, loopback, GPU share, offline) | Check implemented and tested against a mock runtime. **Not yet run on the B580.** |
| 2. Provider interface | Existing gateway; Ollama added as a backend through env-driven model ids. |
| 3. Model registry and aliases | `fast` added. `reasoning` and `large` (`gemma4:31b`) not added: 31B needs CPU offload on 12 GB, and is unmeasured. |
| 4. Benchmarks | Single-prompt runtime check only. No structured-output or tool-call validation yet. |
| 5. Sample consumer | Not started. No downstream repository was changed. |
| 6. Multi-GPU | Not started. |

Model output stays untrusted. A gateway response never authorises a shell command, a file write or an external action on its own. That boundary belongs to whatever consumer is built in phase 5, and is not something the gateway can enforce.
