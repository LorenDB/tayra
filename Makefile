SHELL := bash
CPU_CORES := $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

BAKE_FILES = \
	docker-bake.json \
	docker-bake.api.json \
	docker-bake.front.json

docker-bake.%.json:
	./scripts/build_metadata.py --format bake --bake-target $* --bake-image docker.io/funkwhale/$* > $@

docker-build: $(BAKE_FILES)
	docker buildx bake $(foreach FILE,$(BAKE_FILES), --file $(FILE)) --print $(BUILD_ARGS)
	docker buildx bake $(foreach FILE,$(BAKE_FILES), --file $(FILE)) 		 $(BUILD_ARGS)
