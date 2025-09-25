.PHONY: help format lint clean
.DEFAULT_GOAL := help

## TODO: include MEDIUM severity in security scanning.
TRIVY_SEVERITY := HIGH,CRITICAL

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

trivy-severity: ## Output the Trivy severity levels for use in scripts
	@echo $(TRIVY_SEVERITY)

format: ## Format all Terraform files
	@find . -name "*.tf" -type f | xargs dirname | sort -u | xargs -I {} terraform fmt {}

format-check: ## Check formatting of all Terraform files
	@echo "Checking format..."
	@find . -name "*.tf" -type f | xargs dirname | sort -u | while read dir; do \
		terraform fmt -check=true -diff=true "$$dir" || exit 1; \
	done

validate: ## Validate all Terraform files
	@echo "Validating..."
	@find . -name "*.tf" -type f | xargs dirname | sort -u | while read dir; do \
		echo "  $$dir"; \
		cd "$$dir" && terraform init -backend=false -get=true -upgrade=false >/dev/null && terraform validate && cd - >/dev/null || exit 1; \
	done

lint: ## Lint using tflint
	@echo "Running tflint..."
	@find . -name "*.tf" -type f | xargs dirname | sort -u | while read dir; do \
		echo "  $$dir"; \
		docker run --rm -v "$$(pwd)/$$dir:/data" -t ghcr.io/terraform-linters/tflint --format=compact --minimum-failure-severity=error; \
	done

scan: ## Run security scan using Trivy
	@echo "Running security scan..."
	@docker run --rm -v "$$(pwd):/work" -w /work ghcr.io/aquasecurity/trivy:latest config . --format=table --quiet --exit-code 1 --severity $(TRIVY_SEVERITY)

test: format-check validate lint scan ## Run all tests: format-check, validate, lint, and scan
	@echo "All tests passed!"

clean: ## Clean up .terraform directories and temp files
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete 2>/dev/null || true
	@find . -name "*.tfstate*" -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true