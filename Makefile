up:
	docker compose up -d

down:
	docker compose down

deploy:
	./infra/vps-0/deploy.sh

help:
	@echo "Available commands:"
	@echo "  up            - Start all services"
	@echo "  down          - Stop all services"
	@echo "  deploy        - Deploy to VPS using NixOS"

.PHONY: up down deploy help
