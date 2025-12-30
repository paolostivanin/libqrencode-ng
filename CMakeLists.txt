cmake_minimum_required(VERSION 3.16)

project(libqrencode-ng 
    VERSION 4.2.0 
    DESCRIPTION "A fast and compact QR Code encoding library"
    LANGUAGES C
)

# Project options
option(QRENCODE_BUILD_TOOLS "Build utility tools" ON)
option(QRENCODE_BUILD_TESTS "Build tests" OFF)
option(QRENCODE_ENABLE_PNG "Enable PNG support" ON)
option(QRENCODE_BUILD_SHARED "Build shared library" OFF)
option(QRENCODE_ENABLE_GPROF "Generate extra code for profiling" OFF)
option(QRENCODE_ENABLE_COVERAGE "Generate extra code for coverage" OFF)
option(QRENCODE_ENABLE_ASAN "Use AddressSanitizer" OFF)

# Set default build type
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

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

find_package(Iconv)

# Check for system headers
include(CheckIncludeFile)
include(CheckFunctionExists)

check_include_file(dlfcn.h HAVE_DLFCN_H)
check_include_file(inttypes.h HAVE_INTTYPES_H)
check_include_file(memory.h HAVE_MEMORY_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(strings.h HAVE_STRINGS_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(getopt.h HAVE_GETOPT_H)
check_include_file(sys/time.h HAVE_SYS_TIME_H)
check_include_file(time.h HAVE_TIME_H)
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

if(QRENCODE_BUILD_SHARED)
    add_library(qrencode SHARED ${QRENCODE_SOURCES} ${QRENCODE_HEADERS})
    set_target_properties(qrencode PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
    )
    if(MSVC)
        set_target_properties(qrencode PROPERTIES
            WINDOWS_EXPORT_ALL_SYMBOLS ON
        )
    endif()
else()
    add_library(qrencode STATIC ${QRENCODE_SOURCES} ${QRENCODE_HEADERS})
endif()

add_library(qrencode::qrencode ALIAS qrencode)

# Target properties
target_include_directories(qrencode
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_compile_definitions(qrencode
    PUBLIC
        MAJOR_VERSION=${PROJECT_VERSION_MAJOR}
        MINOR_VERSION=${PROJECT_VERSION_MINOR}
        MICRO_VERSION=${PROJECT_VERSION_PATCH}
        VERSION="${PROJECT_VERSION}"
        $<$<BOOL:${QRENCODE_BUILD_TESTS}>:WITH_TESTS>
    PRIVATE
        HAVE_SDL=0
        $<$<NOT:$<BOOL:${QRENCODE_BUILD_TESTS}>>:STATIC_IN_RELEASE=static>
        $<$<BOOL:${QRENCODE_BUILD_TESTS}>:STATIC_IN_RELEASE=>
        $<$<BOOL:${HAVE_STRDUP}>:HAVE_STRDUP=1>
        $<$<BOOL:${CMAKE_USE_PTHREADS_INIT}>:HAVE_LIBPTHREAD=1>
)

# Compiler flags
target_compile_options(qrencode
    PRIVATE
        $<$<C_COMPILER_ID:GNU,Clang>:-Wall>
        $<$<BOOL:${QRENCODE_ENABLE_GPROF}>:-pg>
        $<$<BOOL:${QRENCODE_ENABLE_COVERAGE}>:--coverage>
        $<$<BOOL:${QRENCODE_ENABLE_ASAN}>:-fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls>
)

# Linker flags
if(QRENCODE_ENABLE_ASAN)
    target_link_options(qrencode PRIVATE -fsanitize=address)
endif()

if(QRENCODE_ENABLE_COVERAGE)
    target_link_options(qrencode PRIVATE --coverage)
endif()

if(QRENCODE_ENABLE_GPROF)
    target_link_options(qrencode PRIVATE -pg)
endif()

# Link dependencies
if(CMAKE_USE_PTHREADS_INIT)
    target_link_libraries(qrencode PUBLIC Threads::Threads)
endif()

# MSVC specific
if(MSVC)
    target_compile_definitions(qrencode
        PRIVATE
            strcasecmp=_stricmp
            strncasecmp=_strnicmp
            _CRT_SECURE_NO_WARNINGS
            _CRT_NONSTDC_NO_DEPRECATE
    )
    set_target_properties(qrencode PROPERTIES
        DEBUG_POSTFIX "d"
    )
endif()

# ============================================================================
# Command-line tool (qrenc -> qrencode)
# ============================================================================

if(QRENCODE_BUILD_TOOLS)
    add_executable(qrenc src/qrenc.c)
    set_target_properties(qrenc PROPERTIES OUTPUT_NAME qrencode)
    
    target_link_libraries(qrenc PRIVATE qrencode)
    
    if(QRENCODE_ENABLE_PNG AND PNG_FOUND)
        target_compile_definitions(qrenc PRIVATE HAVE_PNG=1)
        target_link_libraries(qrenc PRIVATE PNG::PNG)
    endif()
    
    if(MSVC AND NOT HAVE_GETOPT_H)
        find_path(GETOPT_INCLUDE_DIR getopt.h PATH_SUFFIXES include)
        find_library(GETOPT_LIBRARIES getopt PATH_SUFFIXES lib)
        if(GETOPT_INCLUDE_DIR AND GETOPT_LIBRARIES)
            target_include_directories(qrenc PRIVATE ${GETOPT_INCLUDE_DIR})
            target_link_libraries(qrenc PRIVATE ${GETOPT_LIBRARIES})
        else()
            message(WARNING "getopt not found on MSVC, qrenc tool may not build correctly")
        endif()
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

include(GNUInstallDirs)

# Configure pkg-config file
set(prefix "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix "\${prefix}")
set(libdir "\${prefix}/${CMAKE_INSTALL_LIBDIR}")
set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
set(VERSION "${PROJECT_VERSION}")
set(LIBPTHREAD "$<$<BOOL:${CMAKE_USE_PTHREADS_INIT}>:${CMAKE_THREAD_LIBS_INIT}>")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/libqrencode.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/libqrencode.pc"
    @ONLY
)

# Configure man page
if(QRENCODE_BUILD_TOOLS)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/qrencode.1.in"
        "${CMAKE_CURRENT_BINARY_DIR}/qrencode.1"
        @ONLY
    )
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/qrencode.1"
        DESTINATION ${CMAKE_INSTALL_MANDIR}/man1
    )
endif()

# Install library
install(TARGETS qrencode
    EXPORT qrencode-targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install headers
install(FILES ${QRENCODE_PUBLIC_HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Install pkg-config
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libqrencode.pc"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# Install qrenc tool
if(QRENCODE_BUILD_TOOLS)
    install(TARGETS qrenc
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif()

# Install CMake package config
install(EXPORT qrencode-targets
    FILE qrencode-targets.cmake
    NAMESPACE qrencode::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode
)

include(CMakePackageConfigHelpers)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/qrencode-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-config.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/qrencode-config-version.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/qrencode
)

# ============================================================================
# Configuration summary
# ============================================================================

message(STATUS "============================================================")
message(STATUS " ${PROJECT_NAME} ${PROJECT_VERSION} - Configuration Summary")
message(STATUS "============================================================")
message(STATUS "")
message(STATUS " System Configuration:")
message(STATUS "   Platform ................... ${CMAKE_SYSTEM}")
message(STATUS "   Processor .................. ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "   Build type ................. ${CMAKE_BUILD_TYPE}")
message(STATUS "   C Compiler ................. ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
message(STATUS "   Compiler path .............. ${CMAKE_C_COMPILER}")
message(STATUS "")
message(STATUS " Build Options:")
message(STATUS "   Build shared library ....... ${QRENCODE_BUILD_SHARED}")
message(STATUS "   Build tools ................ ${QRENCODE_BUILD_TOOLS}")
message(STATUS "   Build tests ................ ${QRENCODE_BUILD_TESTS}")
message(STATUS "   PNG support ................ ${QRENCODE_ENABLE_PNG}")
message(STATUS "   Enable profiling ........... ${QRENCODE_ENABLE_GPROF}")
message(STATUS "   Enable coverage ............ ${QRENCODE_ENABLE_COVERAGE}")
message(STATUS "   Enable AddressSanitizer .... ${QRENCODE_ENABLE_ASAN}")
message(STATUS "")
message(STATUS " Dependencies:")
message(STATUS "   Threads .................... ${CMAKE_USE_PTHREADS_INIT}")
if(CMAKE_USE_PTHREADS_INIT)
message(STATUS "     Library .................. ${CMAKE_THREAD_LIBS_INIT}")
endif()
message(STATUS "   PNG ........................ ${PNG_FOUND}")
if(PNG_FOUND)
message(STATUS "     Includes ................. ${PNG_INCLUDE_DIRS}")
message(STATUS "     Libraries ................ ${PNG_LIBRARIES}")
endif()
message(STATUS "   Iconv ...................... ${ICONV_FOUND}")
if(ICONV_FOUND)
message(STATUS "     Includes ................. ${ICONV_INCLUDE_DIR}")
message(STATUS "     Libraries ................ ${ICONV_LIBRARIES}")
endif()
message(STATUS "")
message(STATUS " Install Paths:")
message(STATUS "   Prefix ..................... ${CMAKE_INSTALL_PREFIX}")
message(STATUS "   Binaries ................... ${CMAKE_INSTALL_FULL_BINDIR}")
message(STATUS "   Libraries .................. ${CMAKE_INSTALL_FULL_LIBDIR}")
message(STATUS "   Headers .................... ${CMAKE_INSTALL_FULL_INCLUDEDIR}")
message(STATUS "============================================================")
message(STATUS "")
