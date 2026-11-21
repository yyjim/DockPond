DESTINATION ?= $(shell scripts/simulator-destination)
DEMO_PROJECT := DockPondDemo/DockPondDemo.xcodeproj
XCODEBUILD := xcodebuild -quiet -skipMacroValidation -skipPackagePluginValidation

.PHONY: help test test-macros test-gem demo-build demo-test lint format verify

help:
	@echo "make test         Unit tests of the three libraries (iOS Simulator)"
	@echo "make test-macros  TweakDock macro tests (macOS)"
	@echo "make test-gem     tweakdock gem tests"
	@echo "make demo-build   Build the PondDemo app"
	@echo "make demo-test    UI tests of SwiftUIDemo and TweakDemo"
	@echo "make lint         Check format and lint of the changed Swift files"
	@echo "make format       Format and fix the changed Swift files"
	@echo "make verify       lint, test, test-macros, test-gem, and demo-build"
	@echo ""
	@echo "The default simulator is an iPhone on the newest iOS runtime (scripts/simulator-destination)."
	@echo "Set DESTINATION to use a different simulator, for example:"
	@echo "  make test DESTINATION='platform=iOS Simulator,name=iPhone Duo'"

test:
	$(XCODEBUILD) test -scheme DockPond -destination '$(DESTINATION)'

test-macros:
	$(XCODEBUILD) test -scheme TweakDockMacros -destination 'platform=macOS,arch=$(shell uname -m)'

test-gem:
	cd gems/tweakdock && rake

demo-build:
	$(XCODEBUILD) build -project $(DEMO_PROJECT) -scheme PondDemo -destination '$(DESTINATION)'

demo-test:
	$(XCODEBUILD) test -project $(DEMO_PROJECT) -scheme SwiftUIDemo -destination '$(DESTINATION)'
	$(XCODEBUILD) test -project $(DEMO_PROJECT) -scheme TweakDemo -destination '$(DESTINATION)'

lint:
	bundle exec swift-style check

format:
	bundle exec swift-style fix

verify: lint test test-macros test-gem demo-build
