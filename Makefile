.PHONY: help net up down restart logs ps pull ansible-check ansible-apply

# Stacks in start order; a stack is skipped if its compose.yaml is missing
# (e.g. blog/ is a separate repo, cloned optionally).
STACKS := $(foreach s,traefik blog,$(if $(wildcard $(s)/compose.yaml),$(s)))

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

net: ## Create the shared "web" Docker network (idempotent)
	@docker network inspect web >/dev/null 2>&1 || docker network create web

up: net ## Start services
	@for s in $(STACKS); do echo "==> $$s"; docker compose -f $$s/compose.yaml up -d; done

down: ## Stop services
	@for s in $(STACKS); do echo "==> $$s"; docker compose -f $$s/compose.yaml down; done

restart: down up ## Restart services

pull: ## Pull docker images
	@for s in $(STACKS); do docker compose -f $$s/compose.yaml pull; done

ps: ## Container status
	@for s in $(STACKS); do docker compose -f $$s/compose.yaml ps; done

logs: ## Check logs for a service (default: traefik)
	@docker compose -f $(or $(S),traefik)/compose.yaml logs -f --tail=100

ansible-check: ## Ansible dry-run (--check --diff), nothing is changed
	cd ansible && ansible-playbook site.yml --check --diff --ask-become-pass

ansible-apply: ## Apply the Ansible playbook to the server
	cd ansible && ansible-playbook site.yml --diff --ask-become-pass
