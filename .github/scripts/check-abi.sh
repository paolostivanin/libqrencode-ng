#!/bin/sh
# Check that the shared library exports exactly the functions declared in
# the public header, all under the LIBQRENCODE_NG_5 symbol version.
#
# Usage: check-abi.sh <path/to/libqrencode-ng.so.5> <path/to/qrencode.h>
set -eu

lib=$1
header=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

grep -oE '^extern [^(]*\bQR[A-Za-z0-9_]+\(' "$header" \
	| grep -oE 'QR[A-Za-z0-9_]+\($' | tr -d '(' | sort > "$tmp/header"

# Type "A" entries are the version node itself, not functions.
nm -D --defined-only "$lib" | awk '$2 != "A" { sub(/@.*/, "", $3); print $3 }' \
	| sort > "$tmp/exported"

if ! diff -u "$tmp/header" "$tmp/exported"; then
	echo "ERROR: exported symbols differ from the public header" >&2
	exit 1
fi

count=$(wc -l < "$tmp/header")
versioned=$(objdump -T "$lib" | grep -cE 'LIBQRENCODE_NG_5 +QR' || true)
if [ "$versioned" -ne "$count" ]; then
	echo "ERROR: $versioned of $count symbols carry the LIBQRENCODE_NG_5 version" >&2
	exit 1
fi

readelf -d "$lib" | grep -q 'SONAME.*libqrencode-ng\.so\.5' || {
	echo "ERROR: unexpected SONAME" >&2
	exit 1
}

echo "ABI OK: $count public symbols, all versioned LIBQRENCODE_NG_5"
