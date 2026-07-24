SHELL := bash
CPU_CORES := $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

# Load .env for FUNKWHALE_* if present (optional)
-include .env
export

FUNKWHALE_PROTOCOL ?= https
FUNKWHALE_HOSTNAME ?= localhost
FUNKWHALE_URL ?= $(FUNKWHALE_PROTOCOL)://$(FUNKWHALE_HOSTNAME)

.PHONY: help submodule-init submodule-update up down build front-rebuild logs ps

help:
	@echo "Funkwhale + Tayra (source build)"
	@echo ""
	@echo "  make submodule-init   # init/update tayra submodule"
	@echo "  make up               # docker compose up -d --build"
	@echo "  make front-rebuild    # rebuild SPA only (after hostname or Tayra change)"
	@echo "  make down             # docker compose down"
	@echo "  make logs             # follow logs"
	@echo ""
	@echo "FUNKWHALE_URL for front build: $(FUNKWHALE_URL)"

submodule-init:
	git submodule update --init --recursive

submodule-update:
	git submodule update --remote --merge tayra

build:
	docker compose build

up: submodule-init
	@test -f tayra/pubspec.yaml || (echo "ERROR: tayra/ empty — run: git submodule update --init --recursive"; exit 1)
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
