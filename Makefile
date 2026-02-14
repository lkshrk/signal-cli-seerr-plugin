.PHONY: help test test-unit test-integration lint build clean dist check-luacc

# Lua bundler tool
LUACC := luacc
SRC_DIR := src
DIST_DIR := dist
PLUGIN_NAME := seerr-notification
MODULES := seerr-notification.init seerr-notification.constants seerr-notification.templates seerr-notification.image_handler seerr-notification.api_client seerr-notification.response

help:
	@echo "Available commands:"
	@echo "  make test-unit       - Run unit tests (fast, no Docker)"
	@echo "  make test-integration - Run BATS integration tests (starts Docker)"
	@echo "  make test            - Run all tests"
	@echo "  make lint           - Validate Lua syntax"
	@echo "  make build          - Build release package using LuaCC"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make dist           - Create distribution archive"

check-luacc:
	@command -v $(LUACC) >/dev/null 2>&1 || { echo "❌ LuaCC not found. Install with: luarocks install luacc"; exit 1; }

test-unit:
	@echo "Running unit tests..."
	@./spec/unit/run_tests.sh

test-integration:
	@./spec/integration/run_tests.sh

test: test-unit test-integration
	@echo ""
	@echo "✅ All tests passed!"

lint:
	@echo "Validating Lua syntax..."
	@find $(SRC_DIR) -name "*.lua" -exec lua -e "assert(loadfile('{}'))" \;
	@echo "✅ Syntax OK"

build: lint check-luacc
	@echo "Building release package with LuaCC..."
	@rm -rf $(DIST_DIR)
	@mkdir -p $(DIST_DIR)/$(PLUGIN_NAME)
	@$(LUACC) -o $(DIST_DIR)/$(PLUGIN_NAME)/$(PLUGIN_NAME).lua -i $(SRC_DIR) $(MODULES)
	@cp $(SRC_DIR)/$(PLUGIN_NAME).def $(DIST_DIR)/$(PLUGIN_NAME)/
	@echo "✅ Build complete: $(DIST_DIR)/$(PLUGIN_NAME)/"
	@ls -1 $(DIST_DIR)/$(PLUGIN_NAME)/ | sed 's/^/  - /'

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DIST_DIR)/
	@echo "✅ Clean complete"

dist: build
	@echo "Creating distribution archive..."
	@mkdir -p $(DIST_DIR)/release
	@cp -r $(DIST_DIR)/$(PLUGIN_NAME) $(DIST_DIR)/release/
	@cp README.md $(DIST_DIR)/release/
	@cp LICENSE $(DIST_DIR)/release/
	@cd $(DIST_DIR)/release && tar -czf ../$(PLUGIN_NAME)-plugin.tar.gz $(PLUGIN_NAME)/ README.md LICENSE
	@cd $(DIST_DIR)/release && zip -r ../$(PLUGIN_NAME)-plugin.zip $(PLUGIN_NAME)/ README.md LICENSE
	@echo "✅ Distribution created:"
	@echo "  - $(DIST_DIR)/$(PLUGIN_NAME)-plugin.tar.gz"
	@echo "  - $(DIST_DIR)/$(PLUGIN_NAME)-plugin.zip"
