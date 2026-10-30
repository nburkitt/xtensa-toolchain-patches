# ESP32-S3 GCC 14.2 libstdc++ chrono workaround

This repository contains a small patch and build script for working around
an ABI incompatibility in the prebuilt ESP32-S3 GCC 14.2.0 libstdc++.

## Problem

The Espressif ESP32-S3 toolchain uses Newlib with 32-bit `time_t` and
32-bit members in both `struct timeval` and `struct timespec`.

The installed libstdc++ `chrono.o`, however, implements
`std::chrono::system_clock::now()` using `clock_gettime()` and accesses
the returned `timespec` as though its members were 64-bit.

This causes the implementation to interpret the Newlib structure
incorrectly.

The SDK's `clock_gettime()` and `gettimeofday()` functions work correctly.
The incompatibility is in the prebuilt libstdc++ implementation.

## Workaround

The patch introduces the private macro:

    _GLIBCXX_FORCE_GETTIMEOFDAY

When defined, the patched `chrono.cc`:

- Includes `<sys/time.h>`.
- Selects `gettimeofday()` for `system_clock::now()` instead of
  `clock_gettime(CLOCK_REALTIME)`.

The existing `steady_clock::now()` implementation is unchanged and
continues to use `clock_gettime(CLOCK_MONOTONIC)`.

The workaround is enabled when compiling the replacement object with:

    -D_GLIBCXX_FORCE_GETTIMEOFDAY

## Repository contents

    patches/
      gcc-14.2.0/
        0001-libstdcxx-chrono-force-gettimeofday.patch

    scripts/
      build-patched-libstdcxx.sh

    docs/
      source-provenance.md
      verification.md

The build script compiles a replacement `chrono.o`, copies the original
`libstdc++.a`, replaces only its `chrono.o` member, and indexes the
resulting archive.

The installed toolchain is never modified.

## Requirements

- Espressif Xtensa GCC 14.2.0 toolchain for ESP32-S3.
- The matching GCC 14.2.0 source tree.
- GNU `ar`, `ranlib`, `patch`, `realpath`, `sha256sum`, and standard shell utilities.

The compiler and binutils are taken from the supplied toolchain directory.

## Building

Example paths for the original development environment:

    ORIG="$HOME/.platformio/packages/toolchain-xtensa-esp-elf"
    GCC_SOURCE="$HOME/tools/toolchains/xtensa-gcc14-source/gcc-14.2.0"
    ORIGINAL_ARCHIVE="$ORIG/xtensa-esp-elf/lib/esp32s3/libstdc++.a"
    OUTPUT_ARCHIVE="$PWD/build/libstdc++.a"

Build the replacement archive:

    ./scripts/build-patched-libstdcxx.sh \
        "$GCC_SOURCE" \
        "$ORIG" \
        "$ORIGINAL_ARCHIVE" \
        "$OUTPUT_ARCHIVE"

The script requires the original archive and output archive to be
different files.

## Project integration

The replacement archive must be selected by the application build
system in place of the original ESP32-S3 `libstdc++.a`.

The `_GLIBCXX_FORCE_GETTIMEOFDAY` macro is required when compiling
the patched `chrono.cc`. The build script supplies this definition.

Application translation units do not need this macro. They use the
standard `<chrono>` interface and link against the replacement
libstdc++ archive.

The replacement archive and application must use compatible compiler,
target, and ABI settings.

## Verification

The workaround was verified against the ESP32-S3 GCC 14.2.0 toolchain.

The replacement archive was inspected to confirm:

- Exactly one `chrono.o` member.
- Definitions of both `system_clock::now()` and `steady_clock::now()`.
- `system_clock::now()` calls `gettimeofday()`.
- `steady_clock::now()` calls `clock_gettime()` with `CLOCK_MONOTONIC`.
- Both structures are accessed at 32-bit member offsets 0 and 4.

Runtime tests also confirmed that `system_clock` agrees with the SDK time
functions and that `steady_clock` advances monotonically.

See [source provenance](docs/source-provenance.md) and
[verification results](docs/verification.md).
