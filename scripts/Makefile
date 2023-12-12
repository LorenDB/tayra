SHELL = bash
CPU_CORES = $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

.PHONY: install test clean

# Install
VENV = .venv
export POETRY_VIRTUALENVS_IN_PROJECT=true

install: $(VENV)
$(VENV):
	poetry install

test: $(VENV)
	poetry run pytest -s -vv

clean:
	rm -Rf $(VENV)
