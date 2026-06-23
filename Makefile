.DEFAULT_GOAL := help

IMAGE_REPO   := hermes-agent
GIT_SHA      := $(shell git rev-parse --short HEAD)
GIT_FULL_SHA := $(shell git rev-parse HEAD)

define get_aws_repo
  $(shell aws ecr describe-repositories | jq -r '.repositories[] | select(.repositoryName == "$(IMAGE_REPO)" or (.repositoryName | startswith("$(IMAGE_REPO)-"))) | .repositoryUri')
endef

.PHONY: nothing-to-commit
nothing-to-commit: ## Fail if the working tree has uncommitted changes
	@git diff --quiet && git diff --cached --quiet || (echo "Error: working tree is not clean. Commit or stash changes before building."; exit 1)
	@test -z "$$(git status --porcelain)" || (echo "Error: untracked files present. Commit or stash before building."; exit 1)

.PHONY: docker-build
docker-build: nothing-to-commit ## Build the Docker image
	docker build --build-arg HERMES_GIT_SHA=$(GIT_FULL_SHA) -t $(IMAGE_REPO) .
	docker tag $(IMAGE_REPO):latest $(IMAGE_REPO):$(GIT_SHA)

.PHONY: docker-push
docker-push: ## Push Docker image to ECR
	$(eval AWS_REPO := $(or $(AWS_REPO),$(call get_aws_repo)))
	@test -n "$(AWS_REPO)" || (echo "Error: no ECR repository found for $(IMAGE_REPO)."; exit 1)
	docker tag $(IMAGE_REPO):latest $(AWS_REPO):$(GIT_SHA)
	docker push $(AWS_REPO):$(GIT_SHA)
	docker tag $(IMAGE_REPO):latest $(AWS_REPO):latest
	docker push $(AWS_REPO):latest

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-17s %s\n", $$1, $$2}'
