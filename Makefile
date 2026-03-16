###############################################################################
# Makefile – convenience targets for the Spring Boot Terraform project
# Usage:  make <target> ENV=dev|staging|prod
###############################################################################

ENV       ?= dev
VAR_FILE  := environments/$(ENV).tfvars
TF        := terraform

.PHONY: help init validate fmt plan apply destroy output clean

help:
	@echo ""
	@echo "  Spring Boot Infrastructure – Terraform Targets"
	@echo "  ──────────────────────────────────────────────"
	@echo "  make init      ENV=dev     – terraform init"
	@echo "  make validate  ENV=dev     – fmt + validate"
	@echo "  make plan      ENV=dev     – terraform plan"
	@echo "  make apply     ENV=dev     – terraform apply (auto-approve)"
	@echo "  make destroy   ENV=dev     – terraform destroy (prompts)"
	@echo "  make output    ENV=dev     – terraform output"
	@echo "  make clean                 – remove .terraform cache"
	@echo ""

init:
	$(TF) init -upgrade

validate: fmt
	$(TF) validate

fmt:
	$(TF) fmt -recursive

plan:
	$(TF) plan -var-file=$(VAR_FILE) -out=tfplan.$(ENV)

apply:
	$(TF) apply -var-file=$(VAR_FILE) -auto-approve

apply-plan:
	$(TF) apply tfplan.$(ENV)

destroy:
	$(TF) destroy -var-file=$(VAR_FILE)

output:
	$(TF) output

clean:
	rm -rf .terraform tfplan.*
