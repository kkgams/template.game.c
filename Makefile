.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
ZIG ?= zig
PYTHON ?= python3
CURL ?= curl
GAMS_RELEASE_API ?= https://api.github.com/repos/kkgams/gams/releases/latest
PORT ?= 8816
DOCS_PORT ?= 8080
BUILD := build.nosync
WIKI_VERSION := v1.4.0
WIKI_REPOSITORY := https://github.com/justgook/wiki
WIKI_MAKEFILE := $(BUILD)/wiki-$(WIKI_VERSION).mk
WIKI_ENGINE := $(abspath $(BUILD)/wiki-$(WIKI_VERSION))
SOKOL_URL ?= https://raw.githubusercontent.com/floooh/sokol/master
SHDC_URL ?= https://raw.githubusercontent.com/floooh/sokol-tools-bin/master/bin
GAMS_RELEASE_API ?= https://api.github.com/repos/kkgams/gams/releases/latest
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_S),Darwin)
SHDC_PLATFORM := osx
else ifeq ($(UNAME_S),Linux)
SHDC_PLATFORM := linux
else
$(error Unsupported shader-tool host: $(UNAME_S))
endif
ifneq ($(filter $(UNAME_M),arm64 aarch64),)
SHDC_PLATFORM := $(SHDC_PLATFORM)_arm64
else ifneq ($(UNAME_M),x86_64)
$(error Unsupported shader-tool architecture: $(UNAME_M))
endif
SOKOL_SHDC := tools/sokol-shdc/$(SHDC_PLATFORM)/sokol-shdc
SOKOL_HEADERS := $(addprefix game/vendor/,sokol_app.h sokol_gfx.h sokol_log.h sokol_glue.h)
SHADER_SOURCES := $(shell find game -name '*.glsl' -type f | LC_ALL=C sort)
SHADER_HEADERS := $(addsuffix .h,$(SHADER_SOURCES))
SHADER_DEPS_DIR := $(BUILD)/shader-deps
SHADER_DEPFILES := $(addprefix $(SHADER_DEPS_DIR)/,$(addsuffix .d,$(SHADER_SOURCES)))
SHADERS_MISSING_DEPS := $(patsubst $(SHADER_DEPS_DIR)/%.d,%.h,$(filter-out $(wildcard $(SHADER_DEPFILES)),$(SHADER_DEPFILES)))
COMMON := game/main.c game/app.h $(SHADER_HEADERS) $(SOKOL_HEADERS)
WEB_HEADERS := $(shell find game/web/wasm-include -type f)

.PHONY: all deps sokol sokol-shdc native web run play serve serve-docs validate-docs build-docs docs open clean shaders
all: native web
deps: sokol sokol-shdc
sokol: $(SOKOL_HEADERS)
sokol-shdc: $(SOKOL_SHDC)

# No prerequisites: existing dependency files are the snapshot, never refreshed
# by normal builds. Download to a temporary file so failure leaves no target.
$(SOKOL_HEADERS):
	@mkdir -p "$(dir $@)"
	@set -eu; trap 'rm -f "$@.tmp"' EXIT; \
		$(CURL) --fail --location --silent --show-error "$(SOKOL_URL)/$(@F)" --output "$@.tmp"; \
		mv "$@.tmp" "$@"
$(SOKOL_SHDC):
	@mkdir -p "$(dir $@)"
	@set -eu; trap 'rm -f "$@.tmp"' EXIT; \
		$(CURL) --fail --location --silent --show-error "$(SHDC_URL)/$(SHDC_PLATFORM)/sokol-shdc" --output "$@.tmp"; \
		chmod +x "$@.tmp"; \
		mv "$@.tmp" "$@"

# Optional Host download, independent of standalone game builds. Existing app
# directories have no prerequisites and are never refreshed by ordinary Make.
tools/gams.app:
	@test "$(UNAME_S)" = Darwin && test "$(SHDC_PLATFORM)" = osx_arm64 || \
		{ echo 'GAMS release download requires macOS Apple Silicon' >&2; exit 1; }
	@mkdir -p tools "$(BUILD)"
	@set -eu; stage=$$(mktemp -d "$(BUILD)/gams-download.XXXXXX"); \
		trap 'rm -rf "$$stage"' EXIT; \
		$(CURL) --fail --location --silent --show-error "$(GAMS_RELEASE_API)" --output "$$stage/release.json"; \
		url=$$($(PYTHON) -c 'import json, sys; release = json.load(open(sys.argv[1])); assets = [a for a in release["assets"] if a["name"].startswith("GAMS-") and a["name"].endswith("-macos-aarch64.zip")]; assert len(assets) == 1, "Expected exactly one GAMS macOS Apple Silicon ZIP asset"; print(assets[0]["browser_download_url"])' "$$stage/release.json"); \
		$(CURL) --fail --location --silent --show-error "$$url" --output "$$stage/gams.zip"; \
		unzip -q "$$stage/gams.zip" -d "$$stage/unpacked"; \
		test -f "$$stage/unpacked/GAMS.app/Contents/Info.plist"; \
		test -x "$$stage/unpacked/GAMS.app/Contents/MacOS/gams"; \
		mv "$$stage/unpacked/GAMS.app" "$@"

# Missing local depfiles require one regeneration to restore include tracking.
ifneq ($(strip $(SHADERS_MISSING_DEPS)),)
.PHONY: shader-deps-missing
shader-deps-missing:
$(SHADERS_MISSING_DEPS): shader-deps-missing
endif

# Headers stay beside authored shaders and are intended for version control.
# Depfiles are build metadata; downloaded tool executables remain in tools/.
shaders: $(SHADER_HEADERS)
%.glsl.h: %.glsl $(SOKOL_SHDC) Makefile
	@mkdir -p "$(SHADER_DEPS_DIR)/$(dir $<)"
	$(SOKOL_SHDC) -i "$<" -o "$@" -l glsl300es:metal_macos -f sokol \
		--no-log-cmdline --dependency-file "$(SHADER_DEPS_DIR)/$<.d"

native: $(BUILD)/game
web: $(BUILD)/web/game.wasm $(BUILD)/web/index.html $(BUILD)/web/runner.js $(BUILD)/web/gl-bridge.js

$(BUILD)/game: Makefile $(COMMON) game/osx/main.c game/osx/sokol_impl.m
	@mkdir -p $(BUILD)
	@SDK=$$(xcrun --sdk macosx --show-sdk-path) && \
	$(ZIG) build-exe -cflags -Werror=strict-prototypes -- \
		game/osx/sokol_impl.m game/osx/main.c game/main.c \
		-lc -O ReleaseSafe --sysroot "$$SDK" -F/System/Library/Frameworks \
		-framework Metal -framework MetalKit -framework Cocoa \
		-framework QuartzCore -framework Foundation -femit-bin=$@

$(BUILD)/web/game.wasm: Makefile $(COMMON) game/web/main.c $(WEB_HEADERS)
	@mkdir -p $(BUILD)/web
	$(ZIG) build-exe game/web/main.c game/main.c -target wasm32-freestanding \
		-fno-entry -rdynamic -O ReleaseSafe -I game/web/wasm-include -femit-bin=$@

$(BUILD)/web/%: game/web/%
	@mkdir -p $(BUILD)/web
	cp $< $@

run: native
	./$(BUILD)/game

play serve: web
	$(PYTHON) -m http.server $(PORT) --bind 127.0.0.1 --directory $(BUILD)/web

# Retain an existing app; never update it implicitly.
tools/gams.app:
	@test "$(UNAME_S)" = Darwin && test "$(UNAME_M)" = arm64 || \
		{ echo 'GAMS release download requires macOS Apple Silicon' >&2; exit 1; }
	@test ! -e tools/gams-release-notices || \
		{ echo 'tools/gams-release-notices already exists; move it aside before reinstalling GAMS' >&2; exit 1; }
	@mkdir -p tools
	@set -eu; stage=$$(mktemp -d "tools/.gams-download.XXXXXX"); \
		trap 'rm -rf "$$stage"' EXIT; \
		$(CURL) --fail --location --silent --show-error "$(GAMS_RELEASE_API)" --output "$$stage/release.json"; \
		url=$$($(PYTHON) -c 'import json, sys; release = json.load(open(sys.argv[1])); assets = [a for a in release["assets"] if a["name"].startswith("GAMS-") and a["name"].endswith("-macos-aarch64.zip")]; assert len(assets) == 1, "Expected exactly one GAMS macOS Apple Silicon ZIP asset"; print(assets[0]["browser_download_url"])' "$$stage/release.json"); \
		$(CURL) --fail --location --silent --show-error "$$url" --output "$$stage/gams.zip"; \
		unzip -q "$$stage/gams.zip" -d "$$stage/unpacked"; \
		test -f "$$stage/unpacked/GAMS.app/Contents/Info.plist"; \
		test -x "$$stage/unpacked/GAMS.app/Contents/MacOS/gams"; \
		mv "$$stage/unpacked/GAMS.app" "$$stage/GAMS.app"; \
		mv "$$stage/unpacked" tools/gams-release-notices; \
		mv "$$stage/GAMS.app" "$@"

# The local Project loads source files directly; no compiled artifacts are required.
open: tools/gams.app
	GAMS_APP_CWD="$(CURDIR)" ./tools/gams.app/Contents/MacOS/gams

docs: build-docs

$(WIKI_MAKEFILE):
	@mkdir -p "$(@D)"
	@set -eu; trap 'rm -f "$@.tmp"' EXIT; \
		$(CURL) --fail --location --retry 3 "$(WIKI_REPOSITORY)/raw/$(WIKI_VERSION)/Makefile" -o "$@.tmp"; \
		mv "$@.tmp" "$@"

serve-docs validate-docs build-docs: $(WIKI_MAKEFILE)
	$(MAKE) -f "$(WIKI_MAKEFILE)" "$(patsubst %-docs,%,$@)" WIKI_REPOSITORY="$(WIKI_REPOSITORY)" WIKI_VERSION="$(WIKI_VERSION)" WIKI_ENGINE="$(WIKI_ENGINE)" WIKI_SOURCE="$(abspath docs)" WIKI_OUTPUT="$(abspath $(BUILD)/site)" PORT="$(DOCS_PORT)"

# Retain downloaded tools and committed/generated shader headers.
clean:
	rm -rf $(BUILD)

-include $(SHADER_DEPFILES)

.PHONY: open
open: tools/gams.app
	GAMS_APP_CWD="$(CURDIR)" ./tools/gams.app/Contents/MacOS/gams
