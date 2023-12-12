SHELL := bash
CPU_CORES := $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

.PHONY: install lint

install:
	poetry install

lint:
	poetry run pylint \
		--jobs=$(CPU_CORES) \
		--output-format=colorized \
		--recursive=true \
		config funkwhale_api tests
