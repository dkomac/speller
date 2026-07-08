# Speller — common tasks. Run `make` or `make help` to list them.

BIN_DEBUG   := .build/debug/Speller
BIN_RELEASE := .build/release/Speller
APP         := Speller.app

.DEFAULT_GOAL := help
.PHONY: help build test run stop release app install clean

help: ## List available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  make %-9s %s\n", $$1, $$2}'

build: ## Compile the app (debug)
	swift build

test: ## Run the test suite
	swift test

run: build ## Build and launch the app (look for 🔤 in the menu bar)
	-@pkill -x Speller 2>/dev/null || true
	@nohup $(BIN_DEBUG) >/dev/null 2>&1 & \
		echo "Speller launched — look for 🔤 in the menu bar."

stop: ## Quit the running app
	@pkill -x Speller 2>/dev/null && echo "Stopped." || echo "Not running."

release: ## Compile an optimized build
	swift build -c release

app: release ## Package a double-clickable Speller.app (menu-bar app)
	@rm -rf $(APP)
	@mkdir -p $(APP)/Contents/MacOS
	@cp $(BIN_RELEASE) $(APP)/Contents/MacOS/Speller
	@cp packaging/Info.plist $(APP)/Contents/Info.plist
	@echo "Built $(APP) — double-click it, or run 'make install'."

install: app ## Build the app and copy it into /Applications, then launch
	@pkill -x Speller 2>/dev/null || true
	@rm -rf /Applications/$(APP)
	@cp -R $(APP) /Applications/$(APP)
	@open /Applications/$(APP)
	@echo "Installed to /Applications and launched. Add it to Login Items to start at login."

clean: ## Remove build artifacts and the app bundle
	swift package clean
	@rm -rf .build $(APP)
	@echo "Cleaned."
