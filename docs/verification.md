# Verification record

This document records verification performed with the Espressif
ESP32-S3 GCC 14.2.0 toolchain.

## Target ABI

The Newlib target ABI was inspected:

| Type | Size | Member | Offset | Width |
|---|---:|---|---:|---:|
| `time_t` | 4 | | | 32 bits |
| `timespec` | 8 | `tv_sec` | 0 | 32 bits |
| `timespec` | 8 | `tv_nsec` | 4 | 32 bits |
| `timeval` | 8 | `tv_sec` | 0 | 32 bits |
| `timeval` | 8 | `tv_usec` | 4 | 32 bits |

The SDK `clock_gettime()` and `gettimeofday()` implementations
were tested independently and returned valid time values.

## libstdc++ configuration

The GCC 14.2.0 configuration defines:

    _GLIBCXX_USE_CLOCK_REALTIME=1
    _GLIBCXX_USE_CLOCK_MONOTONIC=1
    _GLIBCXX_USE_GETTIMEOFDAY=1

The unmodified source therefore selects `clock_gettime()` for
`system_clock::now()`.

## Patched source compilation

The patched `chrono.cc` was compiled using the installed
ESP32-S3 compiler:

    xtensa-esp-elf-g++ (crosstool-NG esp-14.2.0_20260121) 14.2.0

Relevant compilation options:

    -std=gnu++17
    -D_WANT_USE_LONG_TIME_T
    -D_GLIBCXX_FORCE_GETTIMEOFDAY
    -ffunction-sections
    -fdata-sections

Both clock functions were present in the resulting object.

## Archive construction

Original archive:

    xtensa-esp-elf/lib/esp32s3/libstdc++.a

Original archive SHA-256:

    842bd8bb66b09278ca47ea154a891daa7196f309eb81cd746c5895be94ab36ce

Patched archive:

    build/libstdc++.a

Patched archive SHA-256:

    8ad78c36be24045d767640c8bbcb665f88827a1db3d3d14758576134b06a5b99

The patched archive contains exactly one `chrono.o` member and
defines:

    std::chrono::_V2::system_clock::now()
    std::chrono::_V2::steady_clock::now()

The original installed archive checksum was checked again after
the build and remained unchanged.

## Archived object disassembly

The `chrono.o` member was extracted from the patched archive and
disassembled.

`system_clock::now()` contains the relocation:

    R_XTENSA_SLOT0_OP gettimeofday

It accesses the two 32-bit `timeval` members at offsets 0 and 4.

`steady_clock::now()` contains the relocation:

    R_XTENSA_SLOT0_OP clock_gettime

The clock ID argument is 4 (`CLOCK_MONOTONIC`). It accesses the
two 32-bit `timespec` members at offsets 0 and 4.

This verifies the actual object stored in the replacement archive,
not merely the temporary object produced during compilation.

## Runtime verification

Runtime tests confirmed:

- `system_clock` agrees with SDK `gettimeofday()` and
  `clock_gettime(CLOCK_REALTIME)` to within microseconds.
- `steady_clock` advances monotonically.
- A measured one-second steady-clock interval was approximately
  1005 ms.

Both clock implementations therefore behaved as expected on the
ESP32-S3 target.
