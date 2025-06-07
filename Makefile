# NewHTTPS - Docker Build and Deployment Makefile
# Provides convenient commands for the optimized Docker workflow

.PHONY: help build deploy clean test dev prod staging

# Default target
.DEFAULT_GOAL := help

# Variables
VERSION ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
REGISTRY ?= ghcr.io/yunweifor
PROJECT_NAME := newhttps

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Help target
help: ## Show this help message
	@echo "$(BLUE)NewHTTPS Docker Build and Deployment$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Variables:$(NC)"
	@echo "  VERSION=$(VERSION)"
	@echo "  BUILD_DATE=$(BUILD_DATE)"
	@echo "  REGISTRY=$(REGISTRY)"

# Build targets
build: ## Build all services
	@echo "$(BLUE)Building all services...$(NC)"
	./scripts/build.sh all --version $(VERSION)

build-base: ## Build base image only
	@echo "$(BLUE)Building base image...$(NC)"
	./scripts/build.sh base --version $(VERSION)

build-api: ## Build API service only
	@echo "$(BLUE)Building API service...$(NC)"
	./scripts/build.sh api --version $(VERSION)

build-web: ## Build Web service only
	@echo "$(BLUE)Building Web service...$(NC)"
	./scripts/build.sh web --version $(VERSION)

build-dev: ## Build development images
	@echo "$(BLUE)Building development images...$(NC)"
	./scripts/build.sh all --dev --version $(VERSION)

build-prod: ## Build production images
	@echo "$(BLUE)Building production images...$(NC)"
	./scripts/build.sh all --prod --version $(VERSION)

build-no-cache: ## Build all services without cache
	@echo "$(BLUE)Building all services without cache...$(NC)"
	./scripts/build.sh all --no-cache --version $(VERSION)

# Deployment targets
dev: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	./scripts/deploy.sh dev --build

prod: ## Deploy production environment
	@echo "$(BLUE)Deploying production environment...$(NC)"
	./scripts/deploy.sh prod --build --backup

staging: ## Deploy staging environment
	@echo "$(BLUE)Deploying staging environment...$(NC)"
	./scripts/deploy.sh staging --build

# Quick deployment targets
dev-quick: ## Start development environment (no build)
	@echo "$(BLUE)Starting development environment (quick)...$(NC)"
	./scripts/deploy.sh dev

prod-quick: ## Deploy production environment (no build)
	@echo "$(BLUE)Deploying production environment (quick)...$(NC)"
	./scripts/deploy.sh prod

# Docker Compose shortcuts
up: ## Start services using docker-compose
	docker-compose -f docker-compose.optimized.yml up -d

up-dev: ## Start development services
	docker-compose -f docker-compose.dev.yml up -d

down: ## Stop all services
	docker-compose -f docker-compose.optimized.yml down
	docker-compose -f docker-compose.dev.yml down

restart: ## Restart all services
	$(MAKE) down
	$(MAKE) up

logs: ## Show service logs
	docker-compose -f docker-compose.optimized.yml logs -f

logs-api: ## Show API service logs
	docker-compose -f docker-compose.optimized.yml logs -f newhttps-api

logs-web: ## Show Web service logs
	docker-compose -f docker-compose.optimized.yml logs -f newhttps-web

status: ## Show service status
	docker-compose -f docker-compose.optimized.yml ps

# Testing targets
test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	docker-compose -f docker-compose.dev.yml exec newhttps-api-dev npm test
	docker-compose -f docker-compose.dev.yml exec newhttps-web-dev npm test

test-api: ## Run API tests only
	@echo "$(BLUE)Running API tests...$(NC)"
	docker-compose -f docker-compose.dev.yml exec newhttps-api-dev npm test

test-web: ## Run Web tests only
	@echo "$(BLUE)Running Web tests...$(NC)"
	docker-compose -f docker-compose.dev.yml exec newhttps-web-dev npm test

lint: ## Run linting
	@echo "$(BLUE)Running linting...$(NC)"
	docker-compose -f docker-compose.dev.yml exec newhttps-api-dev npm run lint
	docker-compose -f docker-compose.dev.yml exec newhttps-web-dev npm run lint

# Health check targets
health: ## Check service health
	@echo "$(BLUE)Checking service health...$(NC)"
	@curl -f http://localhost:3000/health && echo "$(GREEN)API: Healthy$(NC)" || echo "$(RED)API: Unhealthy$(NC)"
	@curl -f http://localhost:8080/ >/dev/null 2>&1 && echo "$(GREEN)Web: Healthy$(NC)" || echo "$(RED)Web: Unhealthy$(NC)"

health-api: ## Check API health
	@curl -f http://localhost:3000/health && echo "$(GREEN)API: Healthy$(NC)" || echo "$(RED)API: Unhealthy$(NC)"

health-web: ## Check Web health
	@curl -f http://localhost:8080/ >/dev/null 2>&1 && echo "$(GREEN)Web: Healthy$(NC)" || echo "$(RED)Web: Unhealthy$(NC)"

# Maintenance targets
clean: ## Clean up Docker resources
	@echo "$(BLUE)Cleaning up Docker resources...$(NC)"
	./scripts/build.sh clean

clean-all: ## Clean up all Docker resources (dangerous)
	@echo "$(RED)Cleaning up ALL Docker resources...$(NC)"
	@read -p "Are you sure? This will remove all Docker images, containers, and volumes [y/N]: " confirm && [ "$$confirm" = "y" ]
	docker system prune -a --volumes -f

backup: ## Create backup
	@echo "$(BLUE)Creating backup...$(NC)"
	./scripts/deploy.sh prod --backup

rollback: ## Rollback deployment
	@echo "$(YELLOW)Rolling back deployment...$(NC)"
	./scripts/deploy.sh --rollback

# Registry targets
push: ## Push images to registry
	@echo "$(BLUE)Pushing images to registry...$(NC)"
	./scripts/build.sh all --push --registry $(REGISTRY) --version $(VERSION)

pull: ## Pull images from registry
	@echo "$(BLUE)Pulling images from registry...$(NC)"
	docker pull $(REGISTRY)/$(PROJECT_NAME)-base:$(VERSION)
	docker pull $(REGISTRY)/$(PROJECT_NAME)-api:$(VERSION)
	docker pull $(REGISTRY)/$(PROJECT_NAME)-web:$(VERSION)

# Development helpers
shell-api: ## Open shell in API container
	docker-compose -f docker-compose.dev.yml exec newhttps-api-dev bash

shell-web: ## Open shell in Web container
	docker-compose -f docker-compose.dev.yml exec newhttps-web-dev sh

shell-db: ## Open SQLite shell
	docker-compose -f docker-compose.dev.yml exec newhttps-api-dev sqlite3 /app/data/newhttps.db

# Monitoring targets
stats: ## Show container resource usage
	docker stats

top: ## Show running processes in containers
	docker-compose -f docker-compose.optimized.yml top

# Environment setup
setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN)Created .env file from .env.example$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi
	@echo "$(BLUE)Building base image...$(NC)"
	$(MAKE) build-base
	@echo "$(GREEN)Development environment setup complete!$(NC)"

# Quick start
quick-start: setup dev ## Quick start for new users
	@echo "$(GREEN)NewHTTPS is now running!$(NC)"
	@echo "$(BLUE)Access URLs:$(NC)"
	@echo "  API: http://localhost:3000"
	@echo "  Web: http://localhost:8080"
	@echo "  Health: http://localhost:3000/health"

# Version information
version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "  Version: $(VERSION)"
	@echo "  Build Date: $(BUILD_DATE)"
	@echo "  Registry: $(REGISTRY)"
	@echo "  Project: $(PROJECT_NAME)"

# Docker information
docker-info: ## Show Docker system information
	@echo "$(BLUE)Docker System Information:$(NC)"
	@docker version --format "  Docker Version: {{.Server.Version}}"
	@docker-compose version --short 2>/dev/null | sed 's/^/  Docker Compose: /' || echo "  Docker Compose: Not available"
	@echo "  Images:"
	@docker images $(PROJECT_NAME)* --format "    {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null || echo "    No NewHTTPS images found"
