# ---------------------------------------------------------
# Misc.
# ---------------------------------------------------------

# Set the default goal.
.DEFAULT_GOAL := redeploy

# Tell Docker to build images in parallel.
COMPOSE_BAKE := true

# Set the Docker Compose profile to "all" if an argument is not provided.
DOCKER_COMPOSE_PROFILE ?= all

# Backend values.
BACKEND_SBOM ?= server/mcp-sbom.json
BACKEND_IMAGE ?= weather-mcp:latest
BACKEND_ADVISORIES ?= server/vex.yaml
BACKEND_VEX ?= server/vex.json
VEX_AUTHOR ?= Robert Norwood
VEX_ID_BASE ?= weather-mcp

# Security scanner configurations.
SEMGREP_CONFIG ?= auto
GRYPE_FAILURE_THRESHOLD ?= medium

# ---------------------------------------------------------
# Update uv.lock.
# ---------------------------------------------------------

.PHONY: lock
.SILENT: lock

lock:
	cd server && uv lock

# ---------------------------------------------------------
# Check for bugs.
# ---------------------------------------------------------

.PHONY: check
.SILENT: check

check:
	ruff check --fix --exclude migrations

# ---------------------------------------------------------
# Format the source code for consistency.
# ---------------------------------------------------------

.PHONY: format
.SILENT: format

format:
	ruff format --exclude migrations

# ---------------------------------------------------------
# Check the source code for vulnerabilities.
# ---------------------------------------------------------

.PHONY: sast
.SILENT: sast

sast:
	semgrep scan --config $(SEMGREP_CONFIG) server/src

# ---------------------------------------------------------
# Build the container images.
# ---------------------------------------------------------

.PHONY: build
.SILENT: build

build: lock check format 
	docker compose --profile $(DOCKER_COMPOSE_PROFILE) build

# ---------------------------------------------------------
# Generate VEX statements.
# ---------------------------------------------------------

.PHONY: vex
.SILENT: vex

define VEX_FILTER
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "$(VEX_ID_BASE)-" + now,
  "author": "$(VEX_AUTHOR)",
  "timestamp": now,
  "version": 1,
  "statements": [
    .advisories[] | {
      "vulnerability": { "name": .vulnerability },
      "products": [ .products[] | { "@id": . } ],
      "status": .status,
      "justification": .justification,
      "impact_statement": .impact_statement
    }
  ]
}
endef
export VEX_FILTER

vex: 
	yq -o=json "$$VEX_FILTER" $(BACKEND_ADVISORIES) > $(BACKEND_VEX)

# ---------------------------------------------------------
# Generate SBOMs for the container images.
# ---------------------------------------------------------

.PHONY: sbom
.SILENT: sbom

sbom: build
	syft $(BACKEND_IMAGE) -o cyclonedx-json=$(BACKEND_SBOM)

# ---------------------------------------------------------
# Scan each container image's dependencies for vulnerabilities.
# ---------------------------------------------------------

.PHONY: dependency-scan
.SILENT: dependency-scan

dependency-scan: sbom vex
	grype db update &&\
	if [ -f "$(BACKEND_VEX)" ]; then \
		grype sbom:$(BACKEND_SBOM) --vex $(BACKEND_VEX) --fail-on $(GRYPE_FAILURE_THRESHOLD); \
	else \
		grype sbom:$(BACKEND_SBOM) --fail-on $(GRYPE_FAILURE_THRESHOLD); \
	fi

# ---------------------------------------------------------
# Start the containers.
# ---------------------------------------------------------

.PHONY: start
.SILENT: start

start: dependency-scan
	docker compose --profile $(DOCKER_COMPOSE_PROFILE) up -d

# ---------------------------------------------------------
# Stop the containers.
# ---------------------------------------------------------

.PHONY: stop
.SILENT: stop

stop: 
	docker compose --profile $(DOCKER_COMPOSE_PROFILE) down

# ---------------------------------------------------------
# Check the status of the containers.
# ---------------------------------------------------------

.PHONY: status
.SILENT: status

status:
	docker compose --profile $(DOCKER_COMPOSE_PROFILE) ps --format "table {{.Name}}\t{{.Ports}}\t{{.Status}}"

# ---------------------------------------------------------
# Deploy the Zarf package.
# ---------------------------------------------------------

.PHONY: deploy
.SILENT: deploy

deploy: dependency-scan
	uds zarf package create --confirm && \
	uds zarf package deploy zarf-package-kaiju-amd64-0.1.0.tar.zst --confirm

# ---------------------------------------------------------
# Remove the Zarf package.
# ---------------------------------------------------------

.PHONY: remove
.SILENT: remove

remove:
	uds zarf package remove kaiju --confirm || true &&\
	uds zarf tools kubectl delete namespace kaiju --ignore-not-found 
	# kubectl patch packages.uds.dev kaiju -n kaiju --type=merge -p '{"metadata":{"finalizers":[]}}'

# ---------------------------------------------------------
# Redeploy the Zarf package.
# ---------------------------------------------------------

.PHONY: redeploy
.SILENT: redeploy

redeploy: remove deploy

# ---------------------------------------------------------
# Update the UDS package.
# ---------------------------------------------------------

.PHONY: update-uds-package
.SILENT: update-uds-package

update-uds-package: 
	uds zarf tools kubectl apply -f uds-package.yaml