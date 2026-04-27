# libqrencode-ng — a fast and compact QR Code encoding library

`libqrencode-ng` is a community-maintained fork of the original
[libqrencode](https://github.com/fukuchi/libqrencode) by Kentaro Fukuchi,
modernized for current Linux and BSD systems.

It is installed as a parallel package: it does not conflict with upstream
`libqrencode` and the two can be installed side by side.

## What's different from upstream

* **Build system:** CMake-only (>= 3.16). All Autotools support has been
  removed.
* **Language standard:** C11 is required. Source has been migrated to use
  `bool`, `stdint` and other C11 idioms.
* **Compilers:** GCC and Clang only.
* **Platforms:** Linux and BSD. Windows-, macOS- and SDL-specific code paths
  have been dropped.
* **Hardening:** ANSI / ANSI256 / ANSIUTF8 / ANSI256UTF8 output buffers are
  now sized correctly to prevent overflows on large inputs.
* **Command-line tool:** added `--eci=N`, `--fnc1-first` and
  `--fnc1-second=AI` for ECI and FNC1 encoding.
* **Sanitizer / coverage builds:** opt-in via `QRENCODE_ENABLE_ASAN`,
  `QRENCODE_ENABLE_UBSAN`, `QRENCODE_ENABLE_COVERAGE`,
  `QRENCODE_ENABLE_GPROF`.
* **Naming:** library, header, pkg-config module, CMake package and CLI tool
  are all suffixed with `-ng` so this package coexists with upstream
  `libqrencode` on the same system. See [Installed files](#installed-files)
  below.

## Specification

`libqrencode-ng` supports QR Code model 2, described in JIS X0510:2004 /
ISO/IEC 18004. Most features of the specification are implemented:

* Numeric, alphanumeric, Japanese kanji (Shift-JIS) or any 8-bit data can be
  embedded
* Optimized encoding of a string
* Structured-append of symbols
* ECI and FNC1 mode
* Micro QR Code

## Requirements

* CMake >= 3.16
* GCC or Clang with C11 support
* `libpng` (optional — required only for PNG output in the CLI tool)
* `iconv` (optional — used by some test programs)
* `pthread` (optional — used for thread-safe builds)

The library itself has no mandatory runtime dependencies.

## Build & install

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
sudo cmake --install build
```

By default this installs to `/usr/local`. To install elsewhere pass
`-DCMAKE_INSTALL_PREFIX=/path` to the configure step.

Useful CMake options:

| Option                         | Default | Description                       |
| ------------------------------ | ------- | --------------------------------- |
| `QRENCODE_BUILD_TOOLS`         | `ON`    | Build the `qrencode-ng` CLI tool  |
| `QRENCODE_BUILD_TESTS`         | `OFF`   | Build the test programs           |
| `QRENCODE_BUILD_SHARED`        | `ON`    | Build a shared library (else static) |
| `QRENCODE_ENABLE_PNG`          | `ON`    | Enable PNG output in the CLI      |
| `QRENCODE_ENABLE_ASAN`         | `OFF`   | Build with AddressSanitizer       |
| `QRENCODE_ENABLE_UBSAN`        | `OFF`   | Build with UndefinedBehaviorSanitizer |
| `QRENCODE_ENABLE_COVERAGE`     | `OFF`   | Build with coverage instrumentation |
| `QRENCODE_ENABLE_GPROF`        | `OFF`   | Build with gprof instrumentation  |

To run the test suite:

```sh
cmake -S . -B build -DQRENCODE_BUILD_TESTS=ON
cmake --build build -j
ctest --test-dir build --output-on-failure
```

## Installed files

| File                                              | Purpose                  |
| ------------------------------------------------- | ------------------------ |
| `<prefix>/lib/libqrencode-ng.so.5`                | Shared library           |
| `<prefix>/include/qrencode-ng/qrencode.h`         | Public C header          |
| `<prefix>/lib/pkgconfig/libqrencode-ng.pc`        | pkg-config module        |
| `<prefix>/lib/cmake/qrencode-ng/`                 | CMake package config     |
| `<prefix>/bin/qrencode-ng`                        | CLI tool                 |
| `<prefix>/share/man/man1/qrencode-ng.1`           | CLI man page             |

## Using the library

With pkg-config:

```sh
cc $(pkg-config --cflags libqrencode-ng) myprog.c \
   $(pkg-config --libs libqrencode-ng) -o myprog
```

In source:

```c
#include <qrencode-ng/qrencode.h>
```

With CMake:

```cmake
find_package(qrencode-ng REQUIRED)
target_link_libraries(myprog PRIVATE qrencode-ng::qrencode-ng)
```

A full API reference can be generated with Doxygen:

```sh
doxygen Doxyfile
```

## Warnings

The library is distributed WITHOUT ANY WARRANTY.

Be careful when exposing the `qrencode-ng` CLI to untrusted input (e.g. from
a CGI script). For example, passing a very large `-s` value can be used to
exhaust memory. Validate parameters at the application boundary.

## License

libqrencode-ng is distributed under the GNU Lesser General Public License,
version 2.1 or any later version. See the [`COPYING`](COPYING) file for the
full license text.

```
Copyright (C) 2006-2018 Kentaro Fukuchi (original libqrencode)
Copyright (C) 2025-2026 Paolo Stivanin and the libqrencode-ng contributors
```

The Reed-Solomon encoder included in this library was originally taken from
the FEC library developed by Phil Karn (KA9Q), distributed under the GNU
LGPL, then rewritten by Kentaro Fukuchi.

```
Copyright (C) 2002, 2003, 2004, 2006 Phil Karn, KA9Q
```

## Reporting issues

Please file bugs and feature requests against this fork at:

  https://github.com/paolostivanin/libqrencode-ng/issues

For issues that affect upstream libqrencode as well, see also:

  https://github.com/fukuchi/libqrencode

## Acknowledgments

QR Code is a registered trademark of DENSO WAVE INCORPORATED in Japan and
other countries.

This fork builds on years of work by Kentaro Fukuchi and the upstream
libqrencode contributors. The full list of upstream contributors is preserved
in the project history; a non-exhaustive selection follows.

* NANKI Haruo — improved lower-case characters encoding
* Katsumi Saito — SPEC file
* Philippe Delcroix — improved mask evaluation
* Yusuke Mihara — structured-append support
* David Dahl — DPI and SVG support
* Adam Shepherd — bug fix for mask evaluation
* Josef Eisl (@zapster) — EPS support
* Colin (@moshen) — ANSI support
* Ralf Ertzinger — ASCII support
* Yutaka Niibe (@gniibe) — various bug fixes
* Dan Storm (@Repox) — SVG support
* Lennart Poettering (@mezcalero) — improved text art
* Yann Droneaud — improved input validation
* Daniel Dörrhöfer (@d4ndo) — RLE option, bug fixes
* Greg Hart — PNG32 support
* Tobias Klauser (@tklauser) — XPM support, bug fixes
* Robert Petersen (@ripetersen) — read input from file
* Michał Górny (@mgorny) — UTF8/ANSIUTF8 reverse mappings, build fixes
* André Klitzing (@misery), Alexey Nikolaev (@aleksey-nikolaev),
  Vilppu Vuorinen (@vilppuvuorinen), @sdf5 — CMake support
* Jonathan Bennett — `--inline` option for qrencode
* András Veres-Szentkirályi — ANSI256UTF8 support

…and many others who contributed bug reports, suggestions and patches over
the lifetime of upstream libqrencode.
