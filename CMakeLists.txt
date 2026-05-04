cmake_minimum_required(VERSION 4.0)

project(Tasks.mac
    VERSION 0.1.0
    LANGUAGES C Swift
)

# C language is declared so that CMake can compile the Objective-C and C
# sources in the dependency targets. ObjC (.m) files are handled by the C
# toolchain on Apple platforms.

enable_testing()

# FindXCTest uses xcrun to locate the framework, avoiding CMake's broken
# platform-path resolution under the macOS 26 calendar-year versioning scheme.
find_package(XCTest REQUIRED)

include(cmake/Dependencies.cmake)

# ---------------------------------------------------------------------------
# TasksCore — core library shared by the app and the unit tests
# ---------------------------------------------------------------------------
add_library(TasksCore STATIC
    Sources/TasksCore/CalDAVClient.swift
    Sources/TasksCore/NextcloudLoginFlow.swift
    Sources/TasksCore/Task.swift
    Sources/TasksCore/URLValidation.swift
    Sources/TasksCore/ServerAddressStorage.swift
)
set_target_properties(TasksCore PROPERTIES
    Swift_LANGUAGE_VERSION 6
)

# ---------------------------------------------------------------------------
# Tasks.mac — main application bundle
# ---------------------------------------------------------------------------
add_executable(Tasks_mac
    Sources/Tasks.mac/TasksApp.swift
    Sources/Tasks.mac/SidebarView.swift
    Sources/Tasks.mac/TaskListView.swift
    Sources/Tasks.mac/TaskStore.swift
    Sources/Tasks.mac/StatusBarView.swift
    Sources/Tasks.mac/Task.swift
    Sources/Tasks.mac/CalDAVClient.swift
)
set_target_properties(Tasks_mac PROPERTIES
    OUTPUT_NAME              "Tasks.mac"
    MACOSX_BUNDLE            TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    Swift_LANGUAGE_VERSION   6
)
target_link_libraries(Tasks_mac PRIVATE TasksCore)

target_sources(Tasks_mac PRIVATE Resources/AppIcon.icns)
set_source_files_properties(Resources/AppIcon.icns PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources
)

# Ad-hoc code signing, equivalent to `codesign --force --sign -` in the
# previous Makefile.
add_custom_command(TARGET Tasks_mac POST_BUILD
    COMMAND codesign --force --sign - "$<TARGET_BUNDLE_DIR:Tasks_mac>"
    COMMENT "Ad-hoc signing Tasks.mac.app"
)

# ---------------------------------------------------------------------------
# Tasks.mac.ut — unit test bundle
# Covers TasksCore in isolation.
# Run with: ctest -R unit-tests
# ---------------------------------------------------------------------------
xctest_add_bundle(Tasks_mac_ut Tasks_mac
    Tests/UnitTests/CalDAVClientTests.swift
    Tests/UnitTests/StubHTTPClient.swift
    Tests/UnitTests/URLValidationTests.swift
    Tests/UnitTests/ServerAddressStorageTests.swift
)
set_target_properties(Tasks_mac_ut PROPERTIES
    Swift_LANGUAGE_VERSION 6
)
target_link_libraries(Tasks_mac_ut PRIVATE
    TasksCore
    Quick
    Nimble
)
# xctest_add_bundle passes -bundle_loader as a bare flag, which swiftc (acting
# as the linker driver) does not understand. Clear and replace with the
# -Xlinker-wrapped form.
set_property(TARGET Tasks_mac_ut PROPERTY LINK_OPTIONS)
target_link_options(Tasks_mac_ut PRIVATE
    "SHELL:-Xlinker -bundle_loader -Xlinker $<TARGET_FILE:Tasks_mac>"
    "SHELL:-L ${XCTEST_DEVELOPER_LIB_PATH}"
)
xctest_add_test(unit-tests Tasks_mac_ut)

# ---------------------------------------------------------------------------
# Tasks.mac.at — acceptance test bundle
# Launches the built app as a subprocess via AppLauncher; requires:
#   1. Tasks_mac to be built (enforced by add_dependencies below)
#   2. The fake CalDAV Python venv to exist (build fake-caldav-deps first)
# Run with: ctest -R acceptance-tests
# ---------------------------------------------------------------------------
xctest_add_bundle(Tasks_mac_at Tasks_mac
    Tests/AcceptanceTests/AcceptanceTests.swift
    Tests/AcceptanceTests/AppLauncher.swift
    Tests/AcceptanceTests/FakeCalDAVServer.swift
    Tests/AcceptanceTests/UIAXHelper.swift
)
set_target_properties(Tasks_mac_at PROPERTIES
    Swift_LANGUAGE_VERSION 6
)
target_link_libraries(Tasks_mac_at PRIVATE
    Quick
    Nimble
    "-framework ApplicationServices"
)
add_dependencies(Tasks_mac_at Tasks_mac)
set_property(TARGET Tasks_mac_at PROPERTY LINK_OPTIONS)
target_link_options(Tasks_mac_at PRIVATE
    "SHELL:-Xlinker -bundle_loader -Xlinker $<TARGET_FILE:Tasks_mac>"
    "SHELL:-L ${XCTEST_DEVELOPER_LIB_PATH}"
)
xctest_add_test(acceptance-tests Tasks_mac_at)

set(FAKE_CALDAV_PATH "${CMAKE_CURRENT_SOURCE_DIR}/Tests/FakeCalDAV")
set_tests_properties(acceptance-tests PROPERTIES
    ENVIRONMENT              "AT_BUNDLE_PATH=$<TARGET_BUNDLE_DIR:Tasks_mac>"
    ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:${FAKE_CALDAV_PATH}/.venv/bin"
)

# ---------------------------------------------------------------------------
# fake-caldav-deps — set up the Radicale Python virtual environment
# Must be run once before invoking the acceptance tests:
#   cmake --build <build-dir> --target fake-caldav-deps
# The command is skipped on subsequent builds if the venv is already current.
# ---------------------------------------------------------------------------
add_custom_command(
    OUTPUT  "${FAKE_CALDAV_PATH}/.venv/bin/radicale"
    COMMAND python3 -m venv "${FAKE_CALDAV_PATH}/.venv"
    COMMAND "${FAKE_CALDAV_PATH}/.venv/bin/pip" install -q -r
            "${FAKE_CALDAV_PATH}/requirements.txt"
    DEPENDS "${FAKE_CALDAV_PATH}/requirements.txt"
    COMMENT "Setting up fake CalDAV Python environment"
)
add_custom_target(fake-caldav-deps
    DEPENDS "${FAKE_CALDAV_PATH}/.venv/bin/radicale"
)

# ---------------------------------------------------------------------------
# lint — static analysis via SwiftLint
# Run with: cmake --build <build-dir> --target lint
# ---------------------------------------------------------------------------
add_custom_target(lint
    COMMAND swiftlint lint
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Running SwiftLint"
)
