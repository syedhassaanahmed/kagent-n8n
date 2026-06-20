# ===========================================================================
# kagent-n8n A2A demo — orchestration Makefile
# Targets wrap the idempotent scripts in scripts/. Safe to re-run.
# ===========================================================================
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

S := scripts

.PHONY: help up demo open-ui status logs down \
        preflight tools ollama kind llm-config kagent-install kagent-agent \
        verify-a2a n8n-up workflow teardown

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "\nkagent-n8n A2A demo — make targets\n\n"} \
	     /^[a-zA-Z0-9_-]+:.*##/{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# --- end-to-end -----------------------------------------------------------
up: preflight tools ollama kind llm-config kagent-install kagent-agent verify-a2a n8n-up workflow ## Full idempotent bring-up of the whole demo
	@echo "Demo is up. Run 'make demo' (headless) or 'make open-ui' (visual)."

demo: ## Headless replay: trigger the n8n workflow and print the A2A response
	@bash $(S)/90-demo-run.sh

open-ui: ## Open the n8n editor on the imported A2A workflow (visual demo)
	@bash $(S)/95-open-ui.sh

status: ## Show status of clusters, pods, containers and the LLM endpoint
	@bash $(S)/98-status.sh

logs: ## Tail kagent controller + n8n logs
	@bash $(S)/97-logs.sh

down: teardown ## Tear everything down (alias for teardown)

# --- individual steps -----------------------------------------------------
preflight: ## Detect OS/arch and verify Docker + resources
	@bash $(S)/00-preflight.sh

tools: ## Install pinned kubectl, kind, helm (and ollama for the ollama provider)
	@bash $(S)/10-install-tools.sh

ollama: ## (ollama provider) start ollama on 0.0.0.0 and pull the model
	@bash $(S)/20-ollama-up.sh

kind: ## Create the Kind cluster with A2A NodePort mappings
	@bash $(S)/30-kind-up.sh

llm-config: ## Resolve/verify the LLM endpoint reachable from the cluster
	@bash $(S)/35-llm-config.sh

kagent-install: ## Install kagent CRDs + controller/UI via Helm OCI charts
	@bash $(S)/40-kagent-install.sh

kagent-agent: ## Apply the ModelConfig + Agent CRs
	@bash $(S)/50-kagent-agent-apply.sh

verify-a2a: ## Smoke-test the live A2A agent card + message/send
	@bash $(S)/55-verify-a2a.sh

n8n-up: ## Bring up n8n (Docker Compose) with the A2A community node
	@bash $(S)/60-n8n-up.sh

workflow: ## Import + activate the n8n A2A demo workflow
	@bash $(S)/70-import-workflow.sh

teardown: ## Delete Kind cluster, stop Compose, optionally stop Ollama
	@bash $(S)/99-teardown.sh
