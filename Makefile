SHELL := bash
CPU_CORES := $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

# Load .env for FUNKWHALE_* if present (optional)
-include .env
export

FUNKWHALE_PROTOCOL ?= https
FUNKWHALE_HOSTNAME ?= localhost
FUNKWHALE_URL ?= $(FUNKWHALE_PROTOCOL)://$(FUNKWHALE_HOSTNAME)

.PHONY: help up down build front-rebuild logs ps

help:
	@echo "Tayra monorepo (Flutter client + Funkwhale API source build)"
	@echo ""
	@echo "  make up               # docker compose up -d --build"
	@echo "  make front-rebuild    # rebuild SPA only (after hostname or client change)"
	@echo "  make down             # docker compose down"
	@echo "  make logs             # follow logs"
	@echo ""
	@echo "Client: flutter run (from repo root)"
	@echo "FUNKWHALE_URL for front build: $(FUNKWHALE_URL)"

build:
	docker compose build

up:
	@test -f pubspec.yaml || (echo "ERROR: pubspec.yaml missing — run from monorepo root"; exit 1)
	mkdir -p data/music data/media data/static
	docker compose up -d --build

front-rebuild:
	docker compose build --no-cache front
	docker compose up -d front

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

# Legacy bake targets (optional; not required for compose deploy)
BAKE_FILES = \
	docker-bake.json \
	docker-bake.api.json \
	docker-bake.front.json

docker-bake.%.json:
	./scripts/build_metadata.py --format bake --bake-target $* --bake-image docker.io/funkwhale/$* > $@

docker-metadata: $(BAKE_FILES)

docker-build: docker-metadata
	docker buildx bake $(foreach FILE,$(BAKE_FILES), --file $(FILE)) --print $(BUILD_ARGS)
	docker buildx bake $(foreach FILE,$(BAKE_FILES), --file $(FILE)) $(BUILD_ARGS)

build-metadata:
	./scripts/build_metadata.py --format env | tee build_metadata.env
