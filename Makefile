.PHONY: default build check

default: check test build

build:
	CGO_ENABLED=0 go build -a --trimpath --installsuffix cgo --ldflags="-s" -o whoami

test:
	go test -v -cover ./...

check:
	golangci-lint run

# =====

SCRIPTS_DIR := ./scripts

.PHONY: setup teardown \
        setup‐clusters teardown‐clusters \
        start‐lb shutdown‐all

setup: setup‐clusters start‐lb
	@echo "All set up: clusters ↑ and LB/monitoring ↑."

setup‐clusters:
	@echo "Creating US+EU clusters (setup-cluster.sh all)..."
	@$(SCRIPTS_DIR)/setup-cluster.sh all

start‐lb:
	@echo "Starting LB & monitoring (setup-lb.sh)..."
	@$(SCRIPTS_DIR)/setup-lb.sh

teardown: shutdown‐all teardown‐clusters
	@echo "Completely torn down: LB, monitoring, clusters."

shutdown‐all:
	@echo "Shutting down LB & monitoring (teardown-lb.sh)..."
	@$(SCRIPTS_DIR)/teardown-lb.sh

teardown‐clusters:
	@echo "Deleting US+EU clusters (teardown-cluster.sh all)..."
	@$(SCRIPTS_DIR)/teardown-cluster.sh all

.PHONY: setup-cluster-us setup-cluster-eu teardown-cluster-us teardown-cluster-eu

setup-cluster-us:
	@echo "Creating only the US cluster..."
	@$(SCRIPTS_DIR)/setup-cluster.sh us

setup-cluster-eu:
	@echo "Creating only the EU cluster..."
	@$(SCRIPTS_DIR)/setup-cluster.sh eu

teardown-cluster-us:
	@echo "Deleting only the US cluster..."
	@$(SCRIPTS_DIR)/teardown-cluster.sh us

teardown-cluster-eu:
	@echo "Deleting only the EU cluster..."
	@$(SCRIPTS_DIR)/teardown-cluster.sh eu