# libqrencode-ng - a fast and compact QR Code encoding library

[![CI](https://github.com/paolostivanin/libqrencode-ng/actions/workflows/ci.yml/badge.svg)](https://github.com/paolostivanin/libqrencode-ng/actions/workflows/ci.yml)

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
* **Compilers:** GCC and Clang only (not enforced at configure time).
* **Platforms:** Linux and BSD. Windows- and macOS-specific code paths have
  been dropped, and the SDL-based viewer is no longer built.
* **Hardening:** the CLI's ANSI / ANSI256 writers use overflow-checked
  buffer sizing, and numeric options (`-s`, `-m`, `-d`, `-v`) are
  range-checked so huge values can no longer overflow image size
  computations.
* **Command-line tool:** added `--eci=NUMBER`, `--fnc1-first` and
  `--fnc1-second=APPID` (0-255) for ECI and FNC1 encoding. They cannot be
  combined with `-M` (Micro QR Code) or `-S` (structured symbols).
* **ABI:** only the public API declared in `qrencode.h` is exported from the
  shared library, with symbol versioning (`LIBQRENCODE_NG_5`), so internal
  symbols never clash with upstream `libqrencode.so.4`.
* **Sanitizer / coverage builds:** opt-in via `QRENCODE_ENABLE_ASAN`,
  `QRENCODE_ENABLE_UBSAN`, `QRENCODE_ENABLE_COVERAGE`,
  `QRENCODE_ENABLE_GPROF`.
* **Naming:** the library, pkg-config module, CMake package and CLI tool all
  use `-ng` names, and the header is installed under `include/qrencode-ng/`,
  so this package coexists with upstream `libqrencode` on the same system.
  See [Installed files](#installed-files) below.

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
* `libpng` (optional - required only for PNG output in the CLI tool; PNG
  support is disabled with a warning if it is not found)
* `iconv` (optional - required for most of the test suite)
* `pthread` (auto-detected - when found, the library is thread-safe)

The library itself has no mandatory runtime dependencies beyond libc.

## Build & install

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
sudo cmake --install build
```

By default this installs to `/usr/local`. To install elsewhere pass
`-DCMAKE_INSTALL_PREFIX=/path` to the configure step.

Useful CMake options:

| Option                     | Default | Description                           |
| -------------------------- | ------- | ------------------------------------- |
| `QRENCODE_BUILD_TOOLS`     | `ON`    | Build the `qrencode-ng` CLI tool      |
| `QRENCODE_BUILD_TESTS`     | `OFF`   | Build the test programs               |
| `QRENCODE_BUILD_SHARED`    | `ON`    | Build a shared library (else static)  |
| `QRENCODE_ENABLE_PNG`      | `ON`    | Enable PNG output in the CLI          |
| `QRENCODE_ENABLE_ASAN`     | `OFF`   | Build with AddressSanitizer           |
| `QRENCODE_ENABLE_UBSAN`    | `OFF`   | Build with UndefinedBehaviorSanitizer |
| `QRENCODE_ENABLE_COVERAGE` | `OFF`   | Build with coverage instrumentation   |
| `QRENCODE_ENABLE_GPROF`    | `OFF`   | Build with gprof instrumentation      |

To run the test suite:

```sh
cmake -S . -B build -DQRENCODE_BUILD_TESTS=ON
cmake --build build -j
(cd build && ctest --output-on-failure)
```

Enabling the tests does not change the installed library.

## Installed files

| File                                      | Purpose                                      |
| ----------------------------------------- | -------------------------------------------- |
| `<libdir>/libqrencode-ng.so.5.0.0`        | Shared library (plus `.so.5`/`.so` symlinks) |
| `<libdir>/libqrencode-ng.a`               | Static library (`QRENCODE_BUILD_SHARED=OFF`) |
| `<prefix>/include/qrencode-ng/qrencode.h` | Public C header                              |
| `<libdir>/pkgconfig/libqrencode-ng.pc`    | pkg-config module                            |
| `<libdir>/cmake/qrencode-ng/`             | CMake package config                         |
| `<prefix>/bin/qrencode-ng`                | CLI tool (`QRENCODE_BUILD_TOOLS=ON`)         |
| `<prefix>/share/man/man1/qrencode-ng.1`   | CLI man page (`QRENCODE_BUILD_TOOLS=ON`)     |

`<libdir>` is `<prefix>/lib`, `<prefix>/lib64` or `<prefix>/lib/<triplet>`
depending on the distribution (see CMake's `GNUInstallDirs`).

## Command-line usage

```sh
# PNG image
qrencode-ng -o hello.png 'Hello, world!'

# Print the symbol in the terminal
qrencode-ng -t ANSIUTF8 'https://example.com'

# UTF-8 data with an ECI header (26 = UTF-8)
qrencode-ng --eci=26 -8 -o utf8.png 'Grüße'
```

See `qrencode-ng --help` or `man qrencode-ng` for all options.

## Using the library

With pkg-config:

```sh
cc $(pkg-config --cflags libqrencode-ng) myprog.c \
   $(pkg-config --libs libqrencode-ng) -o myprog
```

In source:

```c
#include <qrencode.h>
```

pkg-config and the CMake target put `<prefix>/include/qrencode-ng` on the
include path, so this resolves to the libqrencode-ng header even when
upstream's `qrencode.h` is also installed.

With CMake:

```cmake
find_package(qrencode-ng REQUIRED)
target_link_libraries(myprog PRIVATE qrencode-ng::qrencode-ng)
```

A full API reference can be generated with Doxygen (output in `html/`):

```sh
doxygen Doxyfile
```

## Migrating from libqrencode

The C API is source-compatible with upstream libqrencode 4.1.1; only the
build integration changes:

| Upstream libqrencode     | libqrencode-ng                                                 |
| ------------------------ | -------------------------------------------------------------- |
| pkg-config `libqrencode` | pkg-config `libqrencode-ng`                                    |
| `-lqrencode`             | `-lqrencode-ng`                                                |
| (no CMake package)       | `find_package(qrencode-ng)`, target `qrencode-ng::qrencode-ng` |
| `libqrencode.so.4`       | `libqrencode-ng.so.5`                                          |
| `qrencode` CLI           | `qrencode-ng` CLI                                              |
| `#include <qrencode.h>`  | `#include <qrencode.h>` (unchanged)                            |

Applications must be rebuilt: the ABI differs (for example, the
`casesensitive` parameter of `QRcode_encodeString()` is now `bool`). Do not
link both libraries into the same program.

## Warnings

The library is distributed WITHOUT ANY WARRANTY.

Be careful when exposing the `qrencode-ng` CLI to untrusted input (e.g. from
a CGI script). Even within the accepted ranges, large `-s` and `-m` values
produce very large images and can exhaust memory or disk space. Validate
parameters at the application boundary.

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

* NANKI Haruo - improved lower-case characters encoding
* Katsumi Saito - SPEC file
* Philippe Delcroix - improved mask evaluation
* Yusuke Mihara - structured-append support
* David Dahl - DPI and SVG support
* Adam Shepherd - bug fix for mask evaluation
* Josef Eisl (@zapster) - EPS support
* Colin (@moshen) - ANSI support
* Ralf Ertzinger - ASCII support
* Yutaka Niibe (@gniibe) - various bug fixes
* Dan Storm (@Repox) - SVG support
* Lennart Poettering (@mezcalero) - improved text art
* Yann Droneaud - improved input validation
* Daniel Dörrhöfer (@d4ndo) - RLE option, bug fixes
* Greg Hart - PNG32 support
* Tobias Klauser (@tklauser) - XPM support, bug fixes
* Robert Petersen (@ripetersen) - read input from file
* Michał Górny (@mgorny) - UTF8/ANSIUTF8 reverse mappings, build fixes
* André Klitzing (@misery), Alexey Nikolaev (@aleksey-nikolaev),
  Vilppu Vuorinen (@vilppuvuorinen), @sdf5 - CMake support
* Jonathan Bennett - `--inline` option for qrencode
* András Veres-Szentkirályi - ANSI256UTF8 support

...and many others who contributed bug reports, suggestions and patches over
the lifetime of upstream libqrencode.
