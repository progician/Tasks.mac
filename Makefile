EXECUTABLE_NAME := Tasks.mac
BUILD_BIN_PATH := $(shell swift build --show-bin-path)
BUNDLE_PATH := ./.build/dist/Tasks.mac.app
BUNDLE_CONTENTS_PATH := $(BUNDLE_PATH)/Contents
BUNDLE_BIN_PATH := $(BUNDLE_CONTENTS_PATH)/MacOS

ACCEPTANCE_TEST_PATH := ./Tests/AcceptanceTests
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

$(XCTEST_EXECUTABLE): $(ACCEPTANCE_TEST_PATH)/AcceptanceTests.swift $(ACCEPTANCE_TEST_PATH)/UIAXHelper.swift
	swift build --build-tests

test: bundle $(XCTEST_EXECUTABLE)
	AT_BUNDLE_PATH=$(BUNDLE_PATH) swift test --skip-build
