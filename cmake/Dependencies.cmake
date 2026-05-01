include(FetchContent)

# Versions are pinned to the exact revisions from Package.resolved.
FetchContent_Declare(CwlCatchException
    GIT_REPOSITORY https://github.com/mattgallagher/CwlCatchException.git
    GIT_TAG        07b2ba21d361c223e25e3c1e924288742923f08c  # v2.2.1
    SYSTEM
)

FetchContent_Declare(CwlPreconditionTesting
    GIT_REPOSITORY https://github.com/mattgallagher/CwlPreconditionTesting.git
    GIT_TAG        0139c665ebb45e6a9fbdb68aabfd7c39f3fe0071  # v2.2.2
    SYSTEM
)

FetchContent_Declare(Nimble
    GIT_REPOSITORY https://github.com/Quick/Nimble.git
    GIT_TAG        eb5e3d717224fa0d1f6aff3fc2c5e8e81fa1f728  # v11.2.2
    SYSTEM
)

FetchContent_Declare(Quick
    GIT_REPOSITORY https://github.com/Quick/Quick.git
    GIT_TAG        16910e406be96e08923918315388c3e989deac9e  # v6.1.0
    SYSTEM
)

# Populate source trees. The single-argument form does not call add_subdirectory,
# which is correct here: none of these repos ship a CMakeLists.txt.
FetchContent_MakeAvailable(CwlCatchException)
FetchContent_MakeAvailable(CwlPreconditionTesting)
FetchContent_MakeAvailable(Nimble)
FetchContent_MakeAvailable(Quick)

# ---------------------------------------------------------------------------
# Module maps
#
# SPM auto-generates a Clang module map for every ObjC target so Swift can
# import it. CMake does not do this automatically for manually-defined
# targets, so we generate them here with absolute header paths and pass
# them to each dependent Swift target via -Xcc -fmodule-map-file.
# ---------------------------------------------------------------------------
set(_modulemaps_dir "${CMAKE_BINARY_DIR}/modulemaps")

file(WRITE "${_modulemaps_dir}/CwlCatchExceptionSupport/module.modulemap"
    "module CwlCatchExceptionSupport {\n"
    "    header \"${cwlcatchexception_SOURCE_DIR}/Sources/CwlCatchExceptionSupport/include/CwlCatchException.h\"\n"
    "    export *\n"
    "}\n"
)

file(WRITE "${_modulemaps_dir}/CwlMachBadInstructionHandler/module.modulemap"
    "module CwlMachBadInstructionHandler {\n"
    "    header \"${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlMachBadInstructionHandler/include/CwlMachBadInstructionHandler.h\"\n"
    "    export *\n"
    "}\n"
)

file(WRITE "${_modulemaps_dir}/QuickObjCRuntime/module.modulemap"
    "module QuickObjCRuntime {\n"
    "    header \"${quick_SOURCE_DIR}/Sources/QuickObjCRuntime/include/QuickObjCRuntime.h\"\n"
    "    export *\n"
    "}\n"
)

# XCTest lives under the platform developer directory, not the SDK sysroot.
# Derive the Frameworks directory from XCTest_INCLUDE_DIRS so QuickObjCRuntime
# can resolve <XCTest/XCTest.h>.
get_filename_component(_xctest_frameworks_dir "${XCTest_INCLUDE_DIRS}" DIRECTORY)

# The XCTest Swift module lives outside the framework, under Developer/usr/lib.
# _xctest_frameworks_dir is Developer/Library/Frameworks; go up two levels to Developer.
get_filename_component(_xctest_developer_dir "${_xctest_frameworks_dir}" DIRECTORY)
get_filename_component(_xctest_developer_dir "${_xctest_developer_dir}" DIRECTORY)
set(_xctest_swiftmodule_dir "${_xctest_developer_dir}/usr/lib")
# Exposed to the parent scope so test targets can add it as a linker search
# path to find libXCTestSwiftSupport.dylib and the correct deployment-target
# Swift runtime overlays.
set(XCTEST_DEVELOPER_LIB_PATH "${_xctest_developer_dir}/usr/lib")

# ---------------------------------------------------------------------------
# CwlCatchExceptionSupport — Objective-C static library
# Provides catchExceptionOfKind(), used by CwlCatchException.swift.
# ---------------------------------------------------------------------------
add_library(CwlCatchExceptionSupport STATIC
    ${cwlcatchexception_SOURCE_DIR}/Sources/CwlCatchExceptionSupport/CwlCatchException.m
)
target_include_directories(CwlCatchExceptionSupport PUBLIC
    ${cwlcatchexception_SOURCE_DIR}/Sources/CwlCatchExceptionSupport/include
)

# ---------------------------------------------------------------------------
# CwlCatchException — Swift static library
# The Swift sources guard their ObjC import with #if SWIFT_PACKAGE.
# ---------------------------------------------------------------------------
add_library(CwlCatchException STATIC
    ${cwlcatchexception_SOURCE_DIR}/Sources/CwlCatchException/CwlCatchException.swift
)
target_compile_options(CwlCatchException
    PRIVATE
        $<$<COMPILE_LANGUAGE:Swift>:-DSWIFT_PACKAGE>
    INTERFACE
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlCatchExceptionSupport/module.modulemap>"
)
target_compile_options(CwlCatchException
    PRIVATE
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlCatchExceptionSupport/module.modulemap>"
)
target_link_libraries(CwlCatchException PUBLIC CwlCatchExceptionSupport)
set_target_properties(CwlCatchException PROPERTIES
    Swift_LANGUAGE_VERSION 5
)

# ---------------------------------------------------------------------------
# CwlMachBadInstructionHandler — Objective-C + C static library
# Provides the Mach exception handler used by CwlPreconditionTesting.
# ---------------------------------------------------------------------------
add_library(CwlMachBadInstructionHandler STATIC
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlMachBadInstructionHandler/CwlMachBadInstructionHandler.m
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlMachBadInstructionHandler/mach_excServer.c
)
target_include_directories(CwlMachBadInstructionHandler PUBLIC
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlMachBadInstructionHandler/include
)

# ---------------------------------------------------------------------------
# CwlPreconditionTesting — Swift static library
# Only the macOS/iOS Mach-based variant is built; the POSIX variant is not
# needed on this platform.
# ---------------------------------------------------------------------------
add_library(CwlPreconditionTesting STATIC
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlPreconditionTesting/CwlBadInstructionException.swift
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlPreconditionTesting/CwlCatchBadInstruction.swift
    ${cwlpreconditiontesting_SOURCE_DIR}/Sources/CwlPreconditionTesting/CwlDarwinDefinitions.swift
)
target_compile_options(CwlPreconditionTesting
    PRIVATE
        $<$<COMPILE_LANGUAGE:Swift>:-DSWIFT_PACKAGE>
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlMachBadInstructionHandler/module.modulemap>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlCatchExceptionSupport/module.modulemap>"
    INTERFACE
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlMachBadInstructionHandler/module.modulemap>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/CwlCatchExceptionSupport/module.modulemap>"
)
target_link_libraries(CwlPreconditionTesting PUBLIC
    CwlMachBadInstructionHandler
    CwlCatchException
)
set_target_properties(CwlPreconditionTesting PROPERTIES
    Swift_LANGUAGE_VERSION 5
)

# ---------------------------------------------------------------------------
# QuickObjCRuntime — Objective-C static library
# Provides _QuickSpecBase, the ObjC base class for QuickSpec on macOS.
# Quick's Swift sources guard the import with #if canImport(QuickObjCRuntime).
# ---------------------------------------------------------------------------
add_library(QuickObjCRuntime STATIC
    ${quick_SOURCE_DIR}/Sources/QuickObjCRuntime/QuickSpecBase.m
)
target_include_directories(QuickObjCRuntime PUBLIC
    ${quick_SOURCE_DIR}/Sources/QuickObjCRuntime/include
)
target_compile_options(QuickObjCRuntime PRIVATE
    -F${_xctest_frameworks_dir}
)

# ---------------------------------------------------------------------------
# Nimble — Swift static library
# SWIFT_PACKAGE controls:
#   - FileString = StaticString (vs String under the ObjC runtime)
#   - Disables ObjC-facing NMBExpectation and RaisesException APIs
# CwlPreconditionTesting is discovered via canImport() at compile time; no
# additional flag is required beyond linking it.
# ---------------------------------------------------------------------------
file(GLOB_RECURSE NIMBLE_SOURCES
    "${nimble_SOURCE_DIR}/Sources/Nimble/*.swift"
)
add_library(Nimble STATIC ${NIMBLE_SOURCES})
target_compile_options(Nimble PRIVATE
    $<$<COMPILE_LANGUAGE:Swift>:-DSWIFT_PACKAGE>
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-F ${_xctest_frameworks_dir}>"
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-I ${_xctest_swiftmodule_dir}>"
)
target_link_libraries(Nimble PUBLIC CwlPreconditionTesting)
set_target_properties(Nimble PROPERTIES
    Swift_LANGUAGE_VERSION 5
)

# ---------------------------------------------------------------------------
# Quick — Swift static library
# SWIFT_PACKAGE enables the QuickSpec definition in QuickSpec.swift.
# QuickObjCRuntime is then discovered via canImport() and imported.
# ---------------------------------------------------------------------------
file(GLOB_RECURSE QUICK_SOURCES
    "${quick_SOURCE_DIR}/Sources/Quick/*.swift"
)
add_library(Quick STATIC ${QUICK_SOURCES})
target_compile_options(Quick
    PRIVATE
        $<$<COMPILE_LANGUAGE:Swift>:-DSWIFT_PACKAGE>
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-F ${_xctest_frameworks_dir}>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-I ${_xctest_swiftmodule_dir}>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/QuickObjCRuntime/module.modulemap>"
    INTERFACE
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${_modulemaps_dir}/QuickObjCRuntime/module.modulemap>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-F ${_xctest_frameworks_dir}>"
        "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-I ${_xctest_swiftmodule_dir}>"
)
target_link_libraries(Quick PUBLIC QuickObjCRuntime Nimble)
set_target_properties(Quick PROPERTIES
    Swift_LANGUAGE_VERSION 5
)
