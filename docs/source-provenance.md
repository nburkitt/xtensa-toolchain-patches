# Source provenance

## Espressif crosstool-NG release

The installed toolchain identifies itself as:

    xtensa-esp-elf-g++ (crosstool-NG esp-14.2.0_20260121) 14.2.0

The corresponding Espressif crosstool-NG release is:

    Tag: esp-14.2.0_20260121
    Annotated tag object:
      c289974572f436e4ab625099c8b990b5c049cd9a
    Peeled commit:
      83e0002aad6dff93c69707a7b85c8d152f1b17c9

Release source archive:

    crosstool-NG-esp-14.2.0_20260121-src.tar.xz

SHA-256:

    ac107a1a7aa941ab1e35e17dc08bde3ef2b468172ca0eb9ff788a1193b80dbb5

## Installed toolchain configuration

The installed configuration was extracted from:

    share/xtensa-esp-elf-ct-ng.config.bz2

The extracted configuration is:

    xtensa-esp-elf-ct-ng.config

SHA-256:

    3d1cf26eb77814a81c36f4bae42e5a96f0a89e931c11f3a9f5a9989448d68a66

Relevant configuration:

    CT_TARGET_VENDOR="esp"
    CT_LIBC="newlib"
    CT_GCC_VERSION="14.2.0"
    CT_PATCH_BUNDLED=y
    CT_PATCH_ORDER="bundled"
    CT_GCC_PATCH_GLOBAL=y
    CT_GCC_PATCH_ORDER="global"

GCC inherits the global patch order. In this configuration, the
effective patch policy is `bundled`.

The crosstool-NG extraction/patch implementation applies bundled
patches from:

    packages/<package>/<version>/
    packages/<package>/

For GCC 14.2.0, these directories are:

    packages/gcc/14.2.0/
    packages/gcc/

The GCC patch directories were inspected for patches referring to
`chrono.cc`, `clock_gettime`, `timespec`, `timeval`,
`system_clock`, `steady_clock`, `_GLIBCXX_USE_CLOCK`, and
`_GLIBCXX_USE_GETTIMEOFDAY`.

No matching direct modification to `chrono.cc` was found. This
supports using the upstream GCC source as the baseline for this
workaround; it does not rule out every possible indirect effect of
other toolchain patches.

## GNU GCC source

The GCC source archive was obtained from the official GNU source
archive:

    gcc-14.2.0.tar.xz

SHA-256:

    a7b39bc69cbf9e25826c5a60ab26477001f7c08d85cec04bc0e29cabed6f3cc9

This checksum was verified against the checksum recorded in the
Espressif crosstool-NG release's GCC 14.2.0 package metadata.

The relevant upstream source file is:

    libstdc++-v3/src/c++11/chrono.cc

SHA-256 of the unmodified source file:

    d047f3e97a35b5e3c6195d92d58ccaaa124f9e63b2ee0e8f9ebb5442a2e3c50a

## Patch

Patch file:

    patches/gcc-14.2.0/0001-libstdcxx-chrono-force-gettimeofday.patch

SHA-256:

    42602bf8a6381cfd7fde89cb212d6250a0728dd9a896173ba7682787ff767be4

The patch changes two areas of `chrono.cc`:

1. Conditional inclusion of `<sys/time.h>`.
2. Selection of the `system_clock` implementation.

The patch applies with `patch -p1` from the GCC source root.
