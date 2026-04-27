# Contributing to libqrencode-ng

Thanks for your interest in contributing! This document covers how to file
issues, propose changes and what to expect from the review process.

## Reporting bugs

Open an issue at <https://github.com/paolostivanin/libqrencode-ng/issues>.
A good bug report includes:

* The version of `libqrencode-ng` (`qrencode-ng -V` or git revision).
* Your distribution and compiler (`gcc --version` / `clang --version`).
* CMake configure command and any non-default options.
* A minimal reproducer (a short C snippet or a `qrencode-ng` invocation).
* Expected vs. actual behaviour.

For security-sensitive bugs (e.g. crashes on attacker-controlled input,
memory safety issues), please follow the process described in
[`SECURITY.md`](SECURITY.md) instead of opening a public issue.

## Suggesting enhancements

Open an issue describing the use case before opening a pull request for a
non-trivial feature, so we can agree on the approach. Small, self-contained
fixes don't need a prior discussion.

## Submitting changes

1. Fork the repository and create a branch off `master`.
2. Make focused commits with descriptive messages. One logical change per
   commit.
3. Ensure the build is warning-clean with the default flags
   (`-Wall -Wextra -Wpedantic`) under both GCC and Clang if possible.
4. Run the test suite locally:

       cmake -S . -B build -DQRENCODE_BUILD_TESTS=ON
       cmake --build build -j
       ctest --test-dir build --output-on-failure

5. If your change touches encoding logic, please also run an
   AddressSanitizer build:

       cmake -S . -B build-asan -DQRENCODE_BUILD_TESTS=ON \
             -DQRENCODE_ENABLE_ASAN=ON -DQRENCODE_ENABLE_UBSAN=ON
       cmake --build build-asan -j
       ctest --test-dir build-asan --output-on-failure

6. Open a pull request against `master`. Reference any related issue.

## Coding style

* C11. Use `bool`, `stdint` types where appropriate.
* Match the surrounding style: 4-space indentation in new code, K&R-style
  braces, short and descriptive identifiers.
* Avoid introducing new mandatory dependencies.
* Public API changes (anything in `src/qrencode.h`) require an explicit
  discussion in the issue tracker first.
* Don't add platform-specific code paths for Windows or macOS — this fork
  intentionally targets Linux and BSD only.

## Commit messages

Use the imperative mood ("Add foo", not "Added foo" or "Adds foo"). The
first line should be a short summary (~72 characters); add a body if the
change needs explanation, separated by a blank line.

## Licensing

By contributing, you agree that your contributions will be licensed under
the GNU Lesser General Public License, version 2.1 or any later version, the
same license as the rest of the project (see [`COPYING`](COPYING)).
