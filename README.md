# kagent-n8n A2A demo

Demonstrates an **n8n agent workflow** talking to a **kagent-based agent** over the
**A2A (Agent-to-Agent) protocol**. n8n is the A2A *client*; a kagent agent running in
a Kind Kubernetes cluster is the A2A *server*. The agent is powered by a **pluggable
LLM backend** — a small local model on Ollama by default, swappable to any
OpenAI-compatible endpoint by config only.

> Full design, architecture diagram and task breakdown live in
> [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

## Prerequisites

- A Unix-like host: **Linux, WSL2, or macOS** (Intel or Apple Silicon).
- **Docker** (Engine on Linux/WSL2, Docker Desktop on macOS) running.
- `make`, `bash`, `curl`. Remaining tools (`kubectl`, `kind`, `helm`, `ollama`) are
  installed idempotently by `make tools`.

## Quickstart

```bash
cp .env.example .env      # optional; scripts auto-create .env on first run
make up                   # idempotent end-to-end bring-up
make demo                 # headless: trigger the workflow, print the A2A reply
make open-ui              # visual: open the n8n editor to run it live
make down                 # tear everything down
```

Run `make help` to list all targets.

## Configuration

All configuration lives in `.env` (created from `.env.example`). Key knobs:

| Key | Purpose |
|-----|---------|
| `LLM_PROVIDER` | `ollama` (default) \| `openai` \| `azureOpenAI` |
| `LLM_MODEL` | model / deployment name (default `llama3.2:1b`) |
| `LLM_ENDPOINT` | LLM base URL/host (blank = auto-derive for ollama) |
| `LLM_API_KEY` | API key for hosted providers (blank for ollama) |

<!-- Filled in by the docs task: architecture, live-demo walkthrough, troubleshooting. -->

## License

Demo project — see repository for details.
