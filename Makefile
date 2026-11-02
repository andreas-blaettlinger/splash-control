.PHONY: help build app check test lint verify run screenshot

help: ## show targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

# A toolchain that ships the Testing module and matching SPM (Apple's Command Line Tools do not).
# `brew install swift` on Apple Silicon; override for other prefixes/installations.
SWIFT_TOOLCHAIN ?= /opt/homebrew/opt/swift
export PATH := $(SWIFT_TOOLCHAIN)/bin:$(PATH)

# Default to installed release SDK when CLT SDK is mismatched with Swift compiler
SDKROOT ?= $(shell [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ] && echo /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk || xcrun --show-sdk-path)
export SDKROOT

build: ## compile inner loop
	swift build

app: ## assemble dist/Splash.app
	bash Scripts/make-app.sh

check: ## script suites (core + agent-status)
	bash Scripts/check_core.sh && bash Scripts/check_agent_status.sh

test: ## swift-testing suite (Apple toolchain via xcrun)
	# Runs on Apple's toolchain, not the Homebrew default: the Homebrew swift
	# ships no SwiftUIMacros plugin, so the app-logic test target (which
	# depends on the SwiftUI executable target) cannot compile with it.
	# CLT additionally keeps libTestingMacros.dylib in a plugins/testing
	# subdir the macro loader does not scan — the plugin-path flag restores
	# it. Verified 2026-11-01 on CLT swift 6.4 / macOS 26.5 SDK.
	xcrun swift test -Xswiftc -plugin-path -Xswiftc "$$(xcrun --find swift-frontend | xargs dirname)/../lib/swift/host/plugins/testing"

lint: ## formatter gate, zero warnings (strict)
	xcrun swift-format lint --strict --recursive Sources

verify: ## all hard gates: check + test + lint, every one green
	make check && make test && make lint

run: app ## quit, rebuild, relaunch from dist, show process path
	osascript -e 'quit app "Splash"' 2>/dev/null; sleep 1
	open dist/Splash.app && sleep 2 && ps -Ao pid,command | grep "[S]plashControl"

VIEW ?= live
screenshot: ## capture tab (VIEW=settings, default: live)
	./Scripts/screenshot.sh /tmp/shot-$(VIEW).png $(VIEW)
