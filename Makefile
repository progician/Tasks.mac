EXECUTABLE_NAME := Tasks.mac
BUILD_BIN_PATH := $(shell swift build --show-bin-path)
BUNDLE_PATH := ./.build/dist/Tasks.mac.app
BUNDLE_CONTENTS_PATH := $(BUNDLE_PATH)/Contents
BUNDLE_BIN_PATH := $(BUNDLE_CONTENTS_PATH)/MacOS

ACCEPTANCE_TEST_PATH := ./Tests/AcceptanceTests
FAKE_CALDAV_PATH := ./Tests/FakeCalDAV
XCTEST_BUNDLE := $(BUILD_BIN_PATH)/Tasks.macPackageTests.xctest
XCTEST_EXECUTABLE := $(XCTEST_BUNDLE)/Contents/MacOS/Tasks.macPackageTests

all: bundle

$(BUILD_BIN_PATH)/$(EXECUTABLE_NAME): ./Sources/Tasks.mac/SidebarView.swift  ./Sources/Tasks.mac/TasksApp.swift ./Sources/Tasks.mac/TaskListView.swift ./Sources/Tasks.mac/Task.swift
	swift build

$(BUNDLE_BIN_PATH)/$(EXECUTABLE_NAME): $(BUILD_BIN_PATH)/$(EXECUTABLE_NAME)
	mkdir -p ./.build/dist/Tasks.mac.app/Contents/MacOS
	cp $(BUILD_BIN_PATH)/Tasks.mac ./.build/dist/Tasks.mac.app/Contents/MacOS

$(BUNDLE_CONTENTS_PATH)/Info.plist: Info.plist
	mkdir -p ./.build/dist/Tasks.mac.app/Contents/MacOS
	cp Info.plist ./.build/dist/Tasks.mac.app/Contents

app-in-bundle: $(BUNDLE_BIN_PATH)/$(EXECUTABLE_NAME)

plist-in-bundle: $(BUNDLE_CONTENTS_PATH)/Info.plist

bundle: app-in-bundle plist-in-bundle
	codesign --force --sign - $(BUNDLE_PATH)

$(FAKE_CALDAV_PATH)/.venv/bin/radicale: $(FAKE_CALDAV_PATH)/requirements.txt
	python3 -m venv $(FAKE_CALDAV_PATH)/.venv
	$(FAKE_CALDAV_PATH)/.venv/bin/pip install -q -r $(FAKE_CALDAV_PATH)/requirements.txt

fake-caldav-deps: $(FAKE_CALDAV_PATH)/.venv/bin/radicale

$(XCTEST_EXECUTABLE): $(ACCEPTANCE_TEST_PATH)/AcceptanceTests.swift $(ACCEPTANCE_TEST_PATH)/UIAXHelper.swift \
	$(ACCEPTANCE_TEST_PATH)/FakeCalDAVServer.swift $(ACCEPTANCE_TEST_PATH)/AppLauncher.swift
	swift build --build-tests

test: bundle $(XCTEST_EXECUTABLE) fake-caldav-deps
	AT_BUNDLE_PATH=$(BUNDLE_PATH) \
	PATH="$(abspath $(FAKE_CALDAV_PATH)/.venv/bin):$(PATH)" \
	swift test --skip-build

lint:
	swiftlint lint
