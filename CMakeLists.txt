cmake_minimum_required(VERSION 3.16)

project(libqrencode-ng
    VERSION 5.0.0
    DESCRIPTION "A fast and compact QR Code encoding library"
    LANGUAGES C
)

include(GNUInstallDirs)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

# Project options
option(QRENCODE_BUILD_TOOLS "Build utility tools" ON)
option(QRENCODE_BUILD_TESTS "Build tests" OFF)
option(QRENCODE_ENABLE_PNG "Enable PNG support" ON)
option(QRENCODE_BUILD_SHARED "Build shared library" ON)

# Security and debugging options
option(QRENCODE_ENABLE_ASAN "Enable AddressSanitizer for memory error detection" OFF)
option(QRENCODE_ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(QRENCODE_ENABLE_COVERAGE "Enable code coverage reporting" OFF)
option(QRENCODE_ENABLE_GPROF "Enable gprof profiling" OFF)

# Set default build type
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# Instrumentation applies to every target (library, CLI and tests), otherwise
# executables fail to link against an instrumented library or abort at start.
if(QRENCODE_ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls)
    add_link_options(-fsanitize=address)
endif()
if(QRENCODE_ENABLE_UBSAN)
    add_compile_options(-fsanitize=undefined -fno-sanitize-recover=all)
    add_link_options(-fsanitize=undefined)
endif()
if(QRENCODE_ENABLE_COVERAGE)
    add_compile_options(--coverage)
    add_link_options(--coverage)
endif()
if(QRENCODE_ENABLE_GPROF)
    add_compile_options(-pg)
    add_link_options(-pg)
endif()

set(QRENCODE_WARNING_FLAGS "$<$<C_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>")

# Module path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Dependencies
set(CMAKE_THREAD_PREFER_PTHREAD ON)
find_package(Threads)

if(QRENCODE_ENABLE_PNG)
    find_package(PNG)
    if(NOT PNG_FOUND)
        message(WARNING "PNG library not found, disabling PNG support")
        set(QRENCODE_ENABLE_PNG OFF)
    endif()
endif()

if(QRENCODE_BUILD_TESTS)
    find_package(Iconv)
endif()

# Check for system headers
include(CheckIncludeFile)
include(CheckFunctionExists)

check_include_file(sys/time.h HAVE_SYS_TIME_H)
check_include_file(pthread.h HAVE_PTHREAD_H)

check_function_exists(strdup HAVE_STRDUP)

# ============================================================================
# Main library target
# ============================================================================

set(QRENCODE_SOURCES
    src/qrencode.c
    src/qrinput.c
    src/bitstream.c
    src/qrspec.c
    src/rsecc.c
    src/split.c
    src/mask.c
    src/mqrspec.c
    src/mmask.c
)

set(QRENCODE_HEADERS
    src/qrencode.h
    src/qrencode_inner.h
    src/qrinput.h
    src/bitstream.h
    src/qrspec.h
    src/rsecc.h
    src/split.h
    src/mask.h
    src/mqrspec.h
    src/mmask.h
)

set(QRENCODE_PUBLIC_HEADERS
    src/qrencode.h
)

# Absolute paths so tests/ can build its own copy of the library.
list(TRANSFORM QRENCODE_SOURCES PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/")
list(TRANSFORM QRENCODE_HEADERS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/")

set(QRENCODE_VERSION_DEFS
    MAJOR_VERSION=${PROJECT_VERSION_MAJOR}
    MINOR_VERSION=${PROJECT_VERSION_MINOR}
    MICRO_VERSION=${PROJECT_VERSION_PATCH}
    VERSION="${PROJECT_VERSION}"
)
set(QRENCODE_COMMON_PRIVATE_DEFS
    $<$<BOOL:${HAVE_STRDUP}>:HAVE_STRDUP=1>
    $<$<BOOL:${CMAKE_USE_PTHREADS_INIT}>:HAVE_LIBPTHREAD=1>
)

# Production objects, shared by the library and the CLI. The CLI uses a few
# internal functions (e.g. Split_splitStringToQRinput) which the shared
# library does not export.
add_library(qrencode-ng-objects OBJECT ${QRENCODE_SOURCES} ${QRENCODE_HEADERS})
set_target_properties(qrencode-ng-objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(qrencode-ng-objects PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_compile_definitions(qrencode-ng-objects
    PRIVATE
        ${QRENCODE_VERSION_DEFS}
        STATIC_IN_RELEASE=static
        ${QRENCODE_COMMON_PRIVATE_DEFS}
)
target_compile_options(qrencode-ng-objects PRIVATE ${QRENCODE_WARNING_FLAGS})
if(CMAKE_USE_PTHREADS_INIT)
    target_link_libraries(qrencode-ng-objects PUBLIC Threads::Threads)
endif()

# Only the functions declared in qrencode.h are exported from the shared
# library, under the LIBQRENCODE_NG_5 symbol version.
set(QRENCODE_NG_VERSION_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/src/libqrencode-ng.map")

if(QRENCODE_BUILD_SHARED)
    add_library(qrencode-ng SHARED $<TARGET_OBJECTS:qrencode-ng-objects>)
    set_target_properties(qrencode-ng PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
    )
    target_link_options(qrencode-ng PRIVATE
        "LINKER:--version-script=${QRENCODE_NG_VERSION_SCRIPT}"
        "LINKER:--no-undefined-version"
    )
    set_property(TARGET qrencode-ng APPEND PROPERTY LINK_DEPENDS "${QRENCODE_NG_VERSION_SCRIPT}")
else()
    add_library(qrencode-ng STATIC $<TARGET_OBJECTS:qrencode-ng-objects>)
endif()
set_target_properties(qrencode-ng PROPERTIES
    OUTPUT_NAME qrencode-ng
    LINKER_LANGUAGE C
)

add_library(qrencode-ng::qrencode-ng ALIAS qrencode-ng)

target_include_directories(qrencode-ng
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/qrencode-ng>
)

if(CMAKE_USE_PTHREADS_INIT)
    target_link_libraries(qrencode-ng PRIVATE Threads::Threads)
endif()


# ============================================================================
# Command-line tool (qrenc -> qrencode-ng)
# ============================================================================

if(QRENCODE_BUILD_TOOLS)
    add_executable(qrenc src/qrenc.c)
    set_target_properties(qrenc PROPERTIES OUTPUT_NAME qrencode-ng)

    # Linked against the production objects rather than the shared library
    # because the CLI uses internal (non-exported) functions.
    target_link_libraries(qrenc PRIVATE qrencode-ng-objects)
    target_compile_options(qrenc PRIVATE ${QRENCODE_WARNING_FLAGS})

    if(QRENCODE_ENABLE_PNG AND PNG_FOUND)
        target_compile_definitions(qrenc PRIVATE HAVE_PNG=1)
        target_link_libraries(qrenc PRIVATE PNG::PNG)
    endif()

endif()

# ============================================================================
# Tests
# ============================================================================

if(QRENCODE_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# ============================================================================
# Installation
# ============================================================================

# Configure pkg-config file
set(prefix "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix "\${prefix}")
if(IS_ABSOLUTE "${CMAKE_INSTALL_LIBDIR}")
    set(libdir "${CMAKE_INSTALL_LIBDIR}")
else()
    set(libdir "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
endif()
if(IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
    set(includedir "${CMAKE_INSTALL_INCLUDEDIR}")
else()
    set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
endif()
set(VERSION "${PROJECT_VERSION}")
if(CMAKE_USE_PTHREADS_INIT)
    set(LIBPTHREAD "${CMAKE_THREAD_LIBS_INIT}")
else()
    set(LIBPTHREAD "")
endif()

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/libqrencode-ng.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/libqrencode-ng.pc"
    @ONLY
)

# Configure man page
if(QRENCODE_BUILD_TOOLS)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/qrencode-ng.1.in"
        "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng.1"
        @ONLY
    )
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng.1"
        DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
    )
endif()

# Install library
install(TARGETS qrencode-ng
    EXPORT qrencode-ng-targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install headers (into the qrencode-ng/ subdirectory so we coexist with
# upstream libqrencode's qrencode.h)
install(FILES ${QRENCODE_PUBLIC_HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/qrencode-ng
)

# Install pkg-config
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libqrencode-ng.pc"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# Install qrenc tool
if(QRENCODE_BUILD_TOOLS)
    install(TARGETS qrenc
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()

# Install CMake package config
install(EXPORT qrencode-ng-targets
    FILE qrencode-ng-targets.cmake
    NAMESPACE qrencode-ng::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode-ng
)

include(CMakePackageConfigHelpers)

# A static libqrencode-ng carries $<LINK_ONLY:Threads::Threads> in its exported
# interface; a shared one does not.
if(NOT QRENCODE_BUILD_SHARED AND CMAKE_USE_PTHREADS_INIT)
    set(QRENCODE_NG_STATIC_NEEDS_THREADS ON)
else()
    set(QRENCODE_NG_STATIC_NEEDS_THREADS OFF)
endif()

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/qrencode-ng-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng-config.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode-ng
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-ng-config-version.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode-ng
)

# ============================================================================
# Configuration summary
# ============================================================================

message(STATUS "=============================================================================")
message(STATUS " ${PROJECT_NAME} ${PROJECT_VERSION} - Configuration Summary")
message(STATUS "=============================================================================")
message(STATUS "")
message(STATUS " System Configuration:")
message(STATUS "   Platform ........................... ${CMAKE_SYSTEM}")
message(STATUS "   Processor .......................... ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "   Build type ......................... ${CMAKE_BUILD_TYPE}")
message(STATUS "   C Compiler ......................... ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
message(STATUS "   Compiler path ...................... ${CMAKE_C_COMPILER}")
message(STATUS "")
message(STATUS " Build Options:")
message(STATUS "   Build shared library ............... ${QRENCODE_BUILD_SHARED}")
message(STATUS "   Build tools ........................ ${QRENCODE_BUILD_TOOLS}")
message(STATUS "   Build tests ........................ ${QRENCODE_BUILD_TESTS}")
message(STATUS "   PNG support ........................ ${QRENCODE_ENABLE_PNG}")
message(STATUS "   Enable profiling ................... ${QRENCODE_ENABLE_GPROF}")
message(STATUS "   Enable coverage .................... ${QRENCODE_ENABLE_COVERAGE}")
message(STATUS "   Enable AddressSanitizer ............ ${QRENCODE_ENABLE_ASAN}")
message(STATUS "   Enable UndefinedBehaviorSanitizer .. ${QRENCODE_ENABLE_UBSAN}")
message(STATUS "")
message(STATUS " Dependencies:")
message(STATUS "   Threads ............................ ${CMAKE_USE_PTHREADS_INIT}")
if(CMAKE_USE_PTHREADS_INIT)
message(STATUS "     Library .......................... ${CMAKE_THREAD_LIBS_INIT}")
endif()
message(STATUS "   PNG ................................ ${PNG_FOUND}")
if(PNG_FOUND)
message(STATUS "     Includes ......................... ${PNG_INCLUDE_DIRS}")
message(STATUS "     Libraries ........................ ${PNG_LIBRARIES}")
endif()
message(STATUS "   Iconv .............................. ${ICONV_FOUND}")
if(ICONV_FOUND)
message(STATUS "     Includes ......................... ${ICONV_INCLUDE_DIR}")
message(STATUS "     Libraries ........................ ${ICONV_LIBRARIES}")
endif()
message(STATUS "")
message(STATUS " Install Paths:")
message(STATUS "   Prefix ............................. ${CMAKE_INSTALL_PREFIX}")
message(STATUS "   Binaries ........................... ${CMAKE_INSTALL_FULL_BINDIR}")
message(STATUS "   Libraries .......................... ${CMAKE_INSTALL_FULL_LIBDIR}")
message(STATUS "   Headers ............................ ${CMAKE_INSTALL_FULL_INCLUDEDIR}/qrencode-ng")
message(STATUS "=============================================================================")
message(STATUS "")
