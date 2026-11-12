#!/bin/sh
# Build and run a small out-of-tree consumer against an installed
# libqrencode-ng, once through pkg-config and once through find_package().
#
# Usage: consumer-test.sh <install-prefix> [static]
set -eu

prefix=$(cd "$1" && pwd)
mode=${2:-shared}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

libdir=$(dirname "$(find "$prefix" -name 'libqrencode-ng.pc' | head -n 1)")
libdir=$(dirname "$libdir")

cat > "$work/consumer.c" <<'EOF'
#include <stdio.h>
#include <qrencode.h>
#if defined(VERSION) || defined(WITH_TESTS) || defined(MAJOR_VERSION)
#error "libqrencode-ng leaked internal macros"
#endif
int main(void)
{
	QRcode *q = QRcode_encodeString("hello", 0, QR_ECLEVEL_L, QR_MODE_8, true);
	if(q == NULL) return 1;
	printf("%s width=%d\n", QRcode_APIVersionString(), q->width);
	QRcode_free(q);
	return 0;
}
EOF

cat > "$work/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(consumer C)
find_package(qrencode-ng 5 REQUIRED)
add_executable(consumer consumer.c)
target_link_libraries(consumer PRIVATE qrencode-ng::qrencode-ng)
EOF

echo "== pkg-config ($mode)"
export PKG_CONFIG_PATH="$libdir/pkgconfig"
if [ "$mode" = static ]; then
	pcflags="--static"
else
	pcflags=""
fi
# The .pc file records the configured prefix; point it at the staged tree.
cflags=$(pkg-config --define-variable=prefix="$prefix" --cflags libqrencode-ng)
libs=$(pkg-config --define-variable=prefix="$prefix" $pcflags --libs libqrencode-ng)
# shellcheck disable=SC2086
${CC:-cc} -Wall -Wextra -Werror "$work/consumer.c" $cflags $libs \
	-Wl,-rpath,"$libdir" -o "$work/consumer-pc"
"$work/consumer-pc"

echo "== find_package ($mode)"
cmake -S "$work" -B "$work/build" -DCMAKE_PREFIX_PATH="$prefix" \
	-DCMAKE_C_FLAGS="-Wall -Wextra -Werror" -DCMAKE_BUILD_RPATH="$libdir"
cmake --build "$work/build"
"$work/build/consumer"

if [ "$mode" != static ]; then
	objdump -T "$work/build/consumer" | grep -q 'LIBQRENCODE_NG_5' || {
		echo "ERROR: consumer does not bind LIBQRENCODE_NG_5 symbols" >&2
		exit 1
	}
fi

echo "Consumer test OK ($mode)"
