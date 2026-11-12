# Test-only build of the library: internal functions are non-static and the
# test prototypes are enabled. This never touches the installed library, so a
# build with QRENCODE_BUILD_TESTS=ON ships exactly the same libqrencode-ng.
add_library(qrencode-ng-testlib STATIC ${QRENCODE_SOURCES} ${QRENCODE_HEADERS})
target_include_directories(qrencode-ng-testlib PUBLIC "${PROJECT_SOURCE_DIR}/src")
target_compile_definitions(qrencode-ng-testlib
    PUBLIC
        WITH_TESTS
        ${QRENCODE_VERSION_DEFS}
    PRIVATE
        STATIC_IN_RELEASE=
        ${QRENCODE_COMMON_PRIVATE_DEFS}
)
target_compile_options(qrencode-ng-testlib PRIVATE ${QRENCODE_WARNING_FLAGS})
if(CMAKE_USE_PTHREADS_INIT)
    target_link_libraries(qrencode-ng-testlib PUBLIC Threads::Threads)
endif()

add_library(qrencode-ng-test-common STATIC common.c common.h)
target_link_libraries(qrencode-ng-test-common PUBLIC qrencode-ng-testlib)

add_library(qrencode-ng-test-rscode STATIC rscode.c rscode.h)
target_link_libraries(qrencode-ng-test-rscode PUBLIC qrencode-ng-test-common)

macro(MAKE_TEST test_name)
    add_executable(${test_name} ${test_name}.c)
    target_link_libraries(${test_name} qrencode-ng-test-common ${ARGN})
    add_test(NAME ${test_name} COMMAND ${test_name})
endmacro()

# These use internal frame functions, so they link the test library.
if(TARGET PNG::PNG)
    add_executable(create_frame_pattern create_frame_pattern.c)
    target_link_libraries(create_frame_pattern qrencode-ng-test-common PNG::PNG)

    add_executable(create_mqr_frame_pattern create_mqr_frame_pattern.c)
    target_link_libraries(create_mqr_frame_pattern qrencode-ng-test-common PNG::PNG)
endif()

# These only use the public API, so they link the shipped library. This also
# checks at link time that the version script exports what they need.
if(TARGET Threads::Threads)
    add_executable(prof_qrencode prof_qrencode.c)
    target_compile_definitions(prof_qrencode PRIVATE $<$<BOOL:${HAVE_SYS_TIME_H}>:HAVE_SYS_TIME_H>)
    target_link_libraries(prof_qrencode qrencode-ng Threads::Threads)

    if(HAVE_PTHREAD_H)
        add_executable(pthread_qrencode pthread_qrencode.c)
        target_compile_definitions(pthread_qrencode PRIVATE $<$<BOOL:${HAVE_SYS_TIME_H}>:HAVE_SYS_TIME_H>)
        target_link_libraries(pthread_qrencode qrencode-ng Threads::Threads)
    endif()
endif()

MAKE_TEST(test_bitstream)
MAKE_TEST(test_estimatebit)
MAKE_TEST(test_split)

if(TARGET ICONV::ICONV)
    add_library(qrencode-ng-test-decoder STATIC
        decoder.c decoder.h
        datachunk.c datachunk.h
        rsecc_decoder.c rsecc_decoder.h)
    target_link_libraries(qrencode-ng-test-decoder PUBLIC qrencode-ng-test-common ICONV::ICONV)

    MAKE_TEST(test_qrinput qrencode-ng-test-decoder)
    MAKE_TEST(test_qrspec qrencode-ng-test-decoder)
    target_compile_definitions(test_qrspec PRIVATE SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}/")
    MAKE_TEST(test_mqrspec qrencode-ng-test-decoder)
    MAKE_TEST(test_qrencode qrencode-ng-test-decoder)
    MAKE_TEST(test_split_urls qrencode-ng-test-decoder)
    MAKE_TEST(test_monkey qrencode-ng-test-decoder)

    include(CheckCSourceCompiles)
    check_c_source_compiles(
        "int main(){
            const int w = 1;
            char buf[w];
            return 0;
        }"
        FIXED_SIZE_BUFFER_INITIALIZATION)

    if(FIXED_SIZE_BUFFER_INITIALIZATION)
        MAKE_TEST(test_mask qrencode-ng-test-decoder)
        MAKE_TEST(test_mmask qrencode-ng-test-decoder)
        MAKE_TEST(test_rs qrencode-ng-test-rscode qrencode-ng-test-decoder)
    else()
        message(WARNING "VLA probe failed: test_mask, test_mmask and test_rs will not be built.")
    endif()
else()
    message(WARNING "iconv not found: 9 of the 12 unit tests (test_qrinput, test_qrspec, "
        "test_mqrspec, test_qrencode, test_split_urls, test_monkey, test_mask, "
        "test_mmask, test_rs) will NOT be built or run.")
endif()

# ----------------------------------------------------------------------------
# Command-line tool smoke tests
# ----------------------------------------------------------------------------
# Rejections match our own error text instead of using WILL_FAIL, so that a
# sanitizer abort (also a non-zero exit) is never mistaken for a pass.
if(TARGET qrenc)
    set(_cli_fail "Sanitizer|runtime error")

    add_test(NAME cli_ascii COMMAND qrenc -t ASCII -o - foo)
    add_test(NAME cli_eci_8bit COMMAND qrenc --eci=26 -8 -t ASCII -o - foo)
    add_test(NAME cli_fnc1_first COMMAND qrenc --fnc1-first -t ASCII -o - 01)
    add_test(NAME cli_ansi256utf8 COMMAND qrenc -t ANSI256UTF8 -o - foo)
    add_test(NAME cli_structured_asciii
        COMMAND qrenc -S -v 1 -t ASCIIi -o "${CMAKE_CURRENT_BINARY_DIR}/cli_sa.txt"
                "an example of four Structured Append symbols,")
    set_tests_properties(cli_ascii cli_eci_8bit cli_fnc1_first cli_ansi256utf8 cli_structured_asciii
        PROPERTIES FAIL_REGULAR_EXPRESSION "${_cli_fail}")
    # 256-colour escape "\033[38;5;231m"; '.' instead of ';' because CTest
    # treats ';' as a list separator.
    set_tests_properties(cli_ansi256utf8 PROPERTIES PASS_REGULAR_EXPRESSION "38.5.231m")

    function(qrencode_ng_cli_reject name regex)
        add_test(NAME cli_reject_${name} COMMAND qrenc ${ARGN})
        set_tests_properties(cli_reject_${name} PROPERTIES
            PASS_REGULAR_EXPRESSION "${regex}"
            FAIL_REGULAR_EXPRESSION "${_cli_fail}")
    endfunction()

    qrencode_ng_cli_reject(eci_range "Invalid ECI assignment number" --eci=1000000 -t ASCII foo)
    qrencode_ng_cli_reject(fnc1_appid "Invalid FNC1 application identifier" --fnc1-second=256 -t ASCII foo)
    qrencode_ng_cli_reject(micro_eci "Micro QR Code does not support ECI" -M --eci=3 -t ASCII foo)
    qrencode_ng_cli_reject(structured_fnc1 "cannot be combined" -S -v 1 --fnc1-first -o x foo)
    qrencode_ng_cli_reject(structured_eci "cannot be combined" -S -v 1 --eci=26 -o x foo)
    qrencode_ng_cli_reject(huge_size "Invalid size" -s 2000000000 -o /dev/null foo)
    qrencode_ng_cli_reject(huge_margin "Invalid margin" -m 2000000000 -t ASCII foo)
    qrencode_ng_cli_reject(png32_no_output "No output filename" -t PNG32 foo)
endif()
