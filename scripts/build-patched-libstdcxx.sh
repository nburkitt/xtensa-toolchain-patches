#!/usr/bin/env bash
set -euo pipefail

usage()
{
    cat <<USAGE
Usage:
  $0 <gcc-source-root> <toolchain-root> <original-archive> <output-archive>

Example:
  $0 \\
    "\$HOME/tools/toolchains/xtensa-gcc14-source/gcc-14.2.0" \\
    "\$HOME/.platformio/packages/toolchain-xtensa-esp-elf" \\
    "\$HOME/.platformio/packages/toolchain-xtensa-esp-elf/xtensa-esp-elf/lib/esp32s3/libstdc++.a" \\
    "\$HOME/Documents/xtensa-toolchain-patches/build/libstdc++.a"
USAGE
}

if [[ $# -ne 4 ]]; then
    usage >&2
    exit 2
fi

GCC_SOURCE_ROOT=$(realpath "$1")
TOOLCHAIN_ROOT=$(realpath "$2")
ORIGINAL_ARCHIVE=$(realpath "$3")
OUTPUT_ARCHIVE=$(realpath -m "$4")

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PATCH_FILE="$SCRIPT_DIR/../patches/gcc-14.2.0/0001-libstdcxx-chrono-force-gettimeofday.patch"

CHRONO_SOURCE="$GCC_SOURCE_ROOT/libstdc++-v3/src/c++11/chrono.cc"

CXX="$TOOLCHAIN_ROOT/bin/xtensa-esp32s3-elf-g++"
AR="$TOOLCHAIN_ROOT/bin/xtensa-esp-elf-ar"
RANLIB="$TOOLCHAIN_ROOT/bin/xtensa-esp-elf-ranlib"

for file in "$CHRONO_SOURCE" "$PATCH_FILE" "$ORIGINAL_ARCHIVE" \
            "$CXX" "$AR" "$RANLIB"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file not found: $file" >&2
        exit 1
    fi
done

echo "Compiler:"
"$CXX" --version | head -n 1
echo

EXPECTED_CHRONO_SHA256="d047f3e97a35b5e3c6195d92d58ccaaa124f9e63b2ee0e8f9ebb5442a2e3c50a"

if ! echo "$EXPECTED_CHRONO_SHA256  $CHRONO_SOURCE" | sha256sum --check --status; then
    echo "ERROR: GCC chrono.cc does not match the verified GCC 14.2.0 source." >&2
    exit 1
fi

if [[ "$OUTPUT_ARCHIVE" == "$ORIGINAL_ARCHIVE" ]]; then
    echo "ERROR: Output archive must differ from the original archive." >&2
    exit 1
fi

if [[ $(basename "$OUTPUT_ARCHIVE") != "libstdc++.a" ]]; then
    echo "WARNING: Output archive is not named libstdc++.a." >&2
fi

CHRONO_COUNT=$("$AR" t "$ORIGINAL_ARCHIVE" |
    grep -xc 'chrono.o' || true)

if [[ "$CHRONO_COUNT" -ne 1 ]]; then
    echo "ERROR: Expected exactly one chrono.o member; found $CHRONO_COUNT." >&2
    exit 1
fi

OUTPUT_DIR=$(dirname -- "$OUTPUT_ARCHIVE")
mkdir -p "$OUTPUT_DIR"

TMP_DIR=$(mktemp -d)
TMP_ARCHIVE=$(mktemp "$OUTPUT_DIR/.libstdc++.a.tmp.XXXXXX")

cleanup()
{
    rm -rf "$TMP_DIR"
    rm -f "$TMP_ARCHIVE"
}
trap cleanup EXIT

echo "Preparing patched chrono.cc..."

mkdir -p "$TMP_DIR/source/libstdc++-v3/src/c++11"

cp "$CHRONO_SOURCE" \
   "$TMP_DIR/source/libstdc++-v3/src/c++11/chrono.cc"

patch --batch --forward --silent -p1 \
    -d "$TMP_DIR/source" < "$PATCH_FILE"

PATCHED_SOURCE="$TMP_DIR/source/libstdc++-v3/src/c++11/chrono.cc"

echo "Compiling chrono.cc..."

"$CXX" \
    -std=gnu++17 \
    -D_WANT_USE_LONG_TIME_T \
    -D_GLIBCXX_FORCE_GETTIMEOFDAY \
    -ffunction-sections \
    -fdata-sections \
    -c "$PATCHED_SOURCE" \
    -o "$TMP_DIR/chrono.o"

echo "Copying original archive..."

cp "$ORIGINAL_ARCHIVE" "$TMP_ARCHIVE"

echo "Replacing chrono.o..."

"$AR" d "$TMP_ARCHIVE" chrono.o
"$AR" r "$TMP_ARCHIVE" "$TMP_DIR/chrono.o"
"$RANLIB" "$TMP_ARCHIVE"

FINAL_CHRONO_COUNT=$("$AR" t "$TMP_ARCHIVE" |
    grep -xc 'chrono.o' || true)

if [[ "$FINAL_CHRONO_COUNT" -ne 1 ]]; then
    echo "ERROR: Patched archive does not contain exactly one chrono.o." >&2
    exit 1
fi

mv -f "$TMP_ARCHIVE" "$OUTPUT_ARCHIVE"

echo
echo "Patched archive created:"
echo "  $OUTPUT_ARCHIVE"
echo
sha256sum "$OUTPUT_ARCHIVE"
