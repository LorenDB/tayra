SHELL = bash
CPU_CORES = $(shell N=$$(nproc); echo $$(( $$N > 4 ? 4 : $$N )))

# Install
VENV = .venv
export POETRY_VIRTUALENVS_IN_PROJECT=true

$(VENV):
	$(MAKE) install

install:
	poetry install
	poetry run pip install --no-deps --editable ../api

clean:
	git clean -xdf .

# Sphinx
SPHINX_OPTS = -j $(CPU_CORES)
SOURCE_DIR = .
BUILD_DIR = _build

# Dev
dev: $(VENV)
	poetry run _scripts/serve.py

# I18n
LOCALES = en_GB en_US fr

locale-generate: $(VENV)
	poetry run sphinx-build -b gettext $(SOURCE_DIR) locales/gettext $(SPHINX_OPTS)

locale-update: $(VENV)
	poetry run sphinx-intl update -p locales/gettext $(foreach locale,$(LOCALES),-l $(locale))

locale-prune-untranslated: $(VENV)
	poetry run _scripts/locale-prune-untranslated.py

# Swagger
SWAGGER_VERSION = 5.1.2
SWAGGER_RELEASE_URL = https://github.com/swagger-api/swagger-ui/archive/refs/tags/v$(SWAGGER_VERSION).tar.gz
SWAGGER_BUILD_DIR = swagger

swagger:
	mkdir "$(SWAGGER_BUILD_DIR)"
	curl -sSL "$(SWAGGER_RELEASE_URL)" | \
		tar --extract \
			--gzip \
			--directory="$(SWAGGER_BUILD_DIR)" \
			--strip-components=2 \
			"swagger-ui-$(SWAGGER_VERSION)/dist"

	sed -i \
		"s#https://petstore.swagger.io/v2/swagger.json#schema.yml#g" \
		"$(SWAGGER_BUILD_DIR)/swagger-initializer.js"

	cp schema.yml "$(SWAGGER_BUILD_DIR)/schema.yml"

# Releases
$(BUILD_DIR)/releases.json:
	../scripts/releases.py > "$@"

$(BUILD_DIR)/latest.txt:
	../scripts/releases.py -r -q latest.id > "$@"

releases: $(BUILD_DIR)/releases.json $(BUILD_DIR)/latest.txt

# Build
build: $(VENV)
	poetry run sphinx-build $(SOURCE_DIR) $(BUILD_DIR) $(SPHINX_OPTS)

build-translated: $(VENV) locale-prune-untranslated
	for locale in $(LOCALES); do \
		poetry run sphinx-build $(SOURCE_DIR) $(BUILD_DIR)/$$locale $(SPHINX_OPTS) -D language=$$locale; \
	done

build-all: build build-translated releases swagger
