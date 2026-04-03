.PHONY: setup deploy-primary deploy-secondary test-dr switch-dr clean

setup:
	@echo "Setting up environment..."
	chmod +x scripts/*.sh
	./scripts/setup-environment.sh

deploy-primary:
	@echo "Deploying primary region..."
	./scripts/deploy-primary.sh

deploy-secondary:
	@echo "Deploying secondary region..."
	./scripts/deploy-secondary.sh

test-dr:
	@echo "Testing disaster recovery..."
	./scripts/test-failover.sh

switch-dr:
	@echo "Switching to DR region..."
	./scripts/switch-to-dr.sh

clean:
	@echo "Cleaning up resources..."
	./scripts/cleanup.sh

all: setup deploy-primary deploy-secondary test-dr

help:
	@echo "Available targets:"
	@echo "  setup           - Setup environment and check dependencies"
	@echo "  deploy-primary  - Deploy primary region infrastructure"
	@echo "  deploy-secondary- Deploy secondary region infrastructure"
	@echo "  test-dr         - Run disaster recovery tests"
	@echo "  switch-dr       - Switch to disaster recovery region"
	@echo "  clean          - Clean up test resources"
	@echo "  all            - Run complete setup and deployment"
