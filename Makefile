.PHONY: help net up down restart logs ps pull ansible-check ansible-apply

STACKS := traefik blog

help: ## load help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

net: ## Crée le réseau Docker partagé "web" (idempotent)
	@docker network inspect web >/dev/null 2>&1 || docker network create web

up: net ## start services
	@for s in $(STACKS); do echo "==> $$s"; docker compose -f $$s/compose.yaml up -d; done

down: ## stop services
	@for s in $(STACKS); do echo "==> $$s"; docker compose -f $$s/compose.yaml down; done

restart: down up ## Restart services

pull: ## Pull docker images
	@for s in $(STACKS); do docker compose -f $$s/compose.yaml pull; done

ps: ## Container status
	@for s in $(STACKS); do docker compose -f $$s/compose.yaml ps; done

logs: ## Check logs for a service
	@docker compose -f $(or $(S),traefik)/compose.yaml logs -f --tail=100

ansible-check: ## Ansible dry-run (--check --diff), rien n'est modifié
	cd ansible && ansible-playbook site.yml --check --diff --ask-become-pass

ansible-apply: ## Applique le playbook Ansible sur le serveur
	cd ansible && ansible-playbook site.yml --diff --ask-become-pass
