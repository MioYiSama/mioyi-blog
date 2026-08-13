---
title: "Cross-Compilation Tutorial"
tags: [programming-language]
---

“Cross-compilation,” as the name suggests, means compiling on one machine to produce an executable for another machine. In other words, it means producing an executable for a different operating system and/or CPU architecture on one computer.

## Goal

| ⬇️Target \ Host➡️                    | Windows | macOS | Linux |
| ------------------------------------ | ------- | ----- | ----- |
| Windows (same CPU architecture)      | 🚫      |       |       |
| Windows (different CPU architecture) |         |       |       |
| macOS (same CPU architecture)        |         | 🚫    |       |
| macOS (different CPU architecture)   |         |       |       |
| Linux (same CPU architecture)        |         |       | 🚫    |
| Linux (different CPU architecture)   |         |       |       |
| WASM (Browser)                       |         |       |       |
| WASM (WASI)                          |         |       |       |

## Principles

Generating an executable usually involves the following steps:

1. Compile the source code into object files (`.o`) for a specific CPU architecture.
2. Link the object files, the language standard library, and the operating system's standard libraries to generate an executable.

The first step is relatively simple. The compiler only needs to support generating object files for different CPU architectures (LLVM, cross GCC, MinGW, and so on).

The second step usually requires the target machine's headers and standard libraries, also known as a sysroot. The linker must be able to handle syscalls for different operating systems. In addition, it must be able to recognize the target machine's libraries and generate the target machine's executable format (PE, Mach-O, or ELF). LLD is one such linker.

## Obtaining a sysroot

### Windows

<https://github.com/Jake-Shadle/xwin>

```bash
sudo xwin \
  --accept-license \
  --arch x86_64 \
  splat \
  --disable-symlinks \
  --include-debug-libs \
  --include-debug-symbols \
  --use-winsysroot-style \
  --preserve-ms-arch-notation \
  --output "/opt/x86_64-pc-windows-msvc"

sudo xwin \
  --accept-license \
  --arch aarch64 \
  splat \
  --disable-symlinks \
  --include-debug-libs \
  --include-debug-symbols \
  --use-winsysroot-style \
  --preserve-ms-arch-notation \
  --output "/opt/aarch64-pc-windows-msvc"
```

### macOS

> [!WARNING]
>
> According to <https://www.apple.com/legal/sla/docs/xcode.pdf>, using the MacOSX SDK on a non-macOS system violates the terms of Apple's license.

1. Download Xcode: <https://developer.apple.com/download/all/?q=xcode>
2. Write a Dockerfile:

```Dockerfile
FROM debian:unstable-slim

RUN DEBIAN_FRONTEND=noninteractive \
    apt update && \
    apt install -y --no-install-recommends ca-certificates git clang make \
        libssl-dev liblzma-dev libxml2-dev patch cpio libbz2-dev bzip2 && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/tpoechtrager/osxcross /osxcross
WORKDIR /osxcross

RUN ./tools/gen_sdk_package_pbzx.sh --help || true

ENTRYPOINT [ "bash" ]
```

3. Run the following commands (in this example, I mounted Xcode at `/xcode`; adjust the path as needed):

```bash
docker build -t mioyisama/osxcross:latest .

docker run -it --rm -v $(pwd)/xcode:/xcode mioyisama/osxcross:latest

./tools/gen_sdk_package_pbzx.sh /xcode/Xcode_16.4.xip
mv MacOSX*.sdk.tar.bz2 /xcode
```

4. Extract `MacOSX*.sdk.tar.bz2`.

### Linux (GNU)

```Dockerfile
FROM debian:unstable-slim AS sysroot

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update

WORKDIR /workspace

# Make APT believe that no packages are currently installed.
RUN touch /tmp/empty-status \
    && apt-get clean \
    && apt-get install -y \
        --download-only \
        --no-install-recommends \
        -o Dir::State::status=/tmp/empty-status \
        libc6-dev linux-libc-dev libstdc++-16-dev

# Extract the entire dependency closure resolved by APT.
RUN for deb in /var/cache/apt/archives/*.deb; do \
        dpkg-deb -x "$deb" sysroot; \
    done

RUN ln -s usr/lib sysroot/lib \
    && ln -s usr/bin sysroot/bin \
    && ln -s usr/sbin sysroot/sbin \
    && if [ -d sysroot/usr/lib64 ]; then \
        ln -s usr/lib64 sysroot/lib64; \
    fi

FROM scratch
COPY --from=sysroot /workspace/sysroot /
```

```bash
set -euo pipefail

rm -rf /opt/x86_64-unknown-linux-gnu /opt/aarch64-unknown-linux-gnu
docker build --platform linux/amd64 -o /opt/x86_64-unknown-linux-gnu -f linux.Dockerfile .
docker build --platform linux/arm64 -o /opt/aarch64-unknown-linux-gnu -f linux.Dockerfile .
```

### Linux (MUSL)

```Dockerfile
FROM alpine:edge AS sysroot

WORKDIR /workspace

RUN set -eu; \
    mkdir -p apks sysroot; \
    apk update; \
    apk fetch \
        --recursive \
        --output apks \
        musl-dev \
        linux-headers \
        libstdc++-dev \
        libgcc-static; \
    for pkg in apks/*.apk; do \
        apk extract "$pkg" --destination sysroot; \
    done; \
    ln -sfn libgcc_s.so.1 sysroot/usr/lib/libgcc_s.so

FROM scratch
COPY --from=sysroot /workspace/sysroot /
```

```bash
set -euo pipefail

rm -rf /opt/x86_64-unknown-linux-musl /opt/aarch64-unknown-linux-musl
docker build --platform linux/amd64 -o /opt/x86_64-unknown-linux-musl -f linux-musl.Dockerfile .
docker build --platform linux/arm64 -o /opt/aarch64-unknown-linux-musl -f linux-musl.Dockerfile .
```

### WASM (Browser)

Unlike WASI, a browser does not provide syscalls like other environments. It relies on JavaScript to expose interfaces to WASM, so glue code is required.

- For C/C++, you can use <https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html>.
- For Rust, you can use <https://github.com/wasm-bindgen/wasm-bindgen>.

### WASM (WASI)

<https://github.com/WebAssembly/wasi-sdk/releases/latest>

Download `libclang_rt-??.?+m.tar.gz` and `wasi-sysroot-??.?+m.tar.gz`, then extract them.

## Cross-Compilation in C/C++

CMake supports cross-compilation through CMake toolchains; Meson has similar support: <https://mesonbuild.com/Cross-compilation.html>.

| ⬇️Target \ Host➡️                    | Windows         | macOS          | Linux                |
| ------------------------------------ | --------------- | -------------- | -------------------- |
| Windows (same CPU architecture)      | 🚫              | sysroot + LLVM | MinGW/sysroot + LLVM |
| Windows (different CPU architecture) | MSVC Cross Tool | sysroot + LLVM | MinGW/sysroot + LLVM |
| macOS (same CPU architecture)        | sysroot + LLVM  | 🚫             | sysroot + LLVM       |
| macOS (different CPU architecture)   | sysroot + LLVM  | LLVM           | sysroot + LLVM       |
| Linux (same CPU architecture)        | sysroot + LLVM  | sysroot + LLVM | 🚫                   |
| Linux (different CPU architecture)   | sysroot + LLVM  | sysroot + LLVM | cross GCC            |
| WASM (Browser)                       | emscripten      | emscripten     | emscripten           |
| WASM (WASI)                          | LLVM            | LLVM           | LLVM                 |

- CMake configuration example:

```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ARM64)

set(LLVM_ROOT "/opt/homebrew/opt/llvm")
set(LLD_ROOT  "/opt/homebrew/opt/lld")
set(SYSROOT   "/opt/aarch64-pc-windows-msvc")

set(MSVC_VERSION "14.44.17.14")
set(WINSDK_VERSION "10.0.26100")

# ------------------------------------------------------------------------------
# Toolchain
# ------------------------------------------------------------------------------

set(CMAKE_C_COMPILER   "${LLVM_ROOT}/bin/clang")
set(CMAKE_CXX_COMPILER "${LLVM_ROOT}/bin/clang++")

set(CMAKE_AR     "${LLVM_ROOT}/bin/llvm-ar")
set(CMAKE_RANLIB "${LLVM_ROOT}/bin/llvm-ranlib")
set(CMAKE_STRIP  "${LLVM_ROOT}/bin/llvm-strip")
set(CMAKE_RC_COMPILER "${LLVM_ROOT}/bin/llvm-rc")

# Equivalent to:
#   --target=aarch64-pc-windows-msvc
set(CMAKE_C_COMPILER_TARGET   "aarch64-pc-windows-msvc")
set(CMAKE_CXX_COMPILER_TARGET "aarch64-pc-windows-msvc")

# ------------------------------------------------------------------------------
# MSVC / Windows SDK
# ------------------------------------------------------------------------------

set(MSVC_INCLUDE
    "${SYSROOT}/VC/Tools/MSVC/${MSVC_VERSION}/Include"
)

set(WINSDK_INCLUDE
    "${SYSROOT}/Windows Kits/10/Include/${WINSDK_VERSION}"
)

set(MSVC_LIB
    "${SYSROOT}/VC/Tools/MSVC/${MSVC_VERSION}/Lib/arm64"
)

set(WINSDK_LIB
    "${SYSROOT}/Windows Kits/10/Lib/${WINSDK_VERSION}"
)

# ------------------------------------------------------------------------------
# Compiler flags
# ------------------------------------------------------------------------------

set(_INCLUDE_FLAGS
    "-isystem \"${MSVC_INCLUDE}\" \
-isystem \"${WINSDK_INCLUDE}/ucrt\" \
-isystem \"${WINSDK_INCLUDE}/um\" \
-isystem \"${WINSDK_INCLUDE}/shared\""
)

set(CMAKE_C_FLAGS_INIT
    "${_INCLUDE_FLAGS}"
)

set(CMAKE_CXX_FLAGS_INIT
    "${_INCLUDE_FLAGS}"
)

# ------------------------------------------------------------------------------
# Linker
# ------------------------------------------------------------------------------

set(_LINK_FLAGS
    "-fuse-ld=lld \
-B\"${LLD_ROOT}/bin\" \
-Xlinker /libpath:\"${MSVC_LIB}\" \
-Xlinker /libpath:\"${WINSDK_LIB}/um/arm64\" \
-Xlinker /libpath:\"${WINSDK_LIB}/ucrt/arm64\""
)

set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${_LINK_FLAGS}"
)

set(CMAKE_SHARED_LINKER_FLAGS_INIT
    "${_LINK_FLAGS}"
)

set(CMAKE_MODULE_LINKER_FLAGS_INIT
    "${_LINK_FLAGS}"
)

# Equivalent to Meson's c_winlibs.
#
# CMake's Windows platform files already add many of these libraries in many
# configurations, but setting them explicitly makes this toolchain correspond
# to the Meson configuration.
set(CMAKE_C_STANDARD_LIBRARIES_INIT
    "libcmt.lib oldnames.lib kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib"
)

set(CMAKE_CXX_STANDARD_LIBRARIES_INIT
    "libcmt.lib oldnames.lib kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib"
)

# ------------------------------------------------------------------------------
# CMake find_* behavior
# ------------------------------------------------------------------------------

set(CMAKE_FIND_ROOT_PATH "${SYSROOT}")

# Build tools should come from macOS.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Target headers/libraries/packages should come from the Windows sysroot.
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
```

- Meson configuration example:

```ini
# aarch64 Windows, MSVC CRT — Homebrew LLVM 22 + lld-link, sysroot /opt/aarch64-pc-windows-msvc
[binaries]
c = '/opt/homebrew/opt/llvm/bin/clang'
cpp = '/opt/homebrew/opt/llvm/bin/clang++'
ar = '/opt/homebrew/opt/llvm/bin/llvm-ar'
ranlib = '/opt/homebrew/opt/llvm/bin/llvm-ranlib'
strip = '/opt/homebrew/opt/llvm/bin/llvm-strip'

[host_machine]
system = 'windows'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[built-in options]
c_args = ['--target=aarch64-pc-windows-msvc',
          '-isystem', '/opt/aarch64-pc-windows-msvc/VC/Tools/MSVC/14.44.17.14/Include',
          '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/ucrt',
          '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/um',
          '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/shared']
cpp_args = ['--target=aarch64-pc-windows-msvc',
            '-isystem', '/opt/aarch64-pc-windows-msvc/VC/Tools/MSVC/14.44.17.14/Include',
            '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/ucrt',
            '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/um',
            '-isystem', '/opt/aarch64-pc-windows-msvc/Windows Kits/10/Include/10.0.26100/shared']
c_link_args = ['--target=aarch64-pc-windows-msvc', '-fuse-ld=lld', '-B/opt/homebrew/opt/lld/bin',
               '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/VC/Tools/MSVC/14.44.17.14/Lib/arm64',
               '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/Windows Kits/10/Lib/10.0.26100/um/arm64',
               '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/Windows Kits/10/Lib/10.0.26100/ucrt/arm64']
cpp_link_args = ['--target=aarch64-pc-windows-msvc', '-fuse-ld=lld', '-B/opt/homebrew/opt/lld/bin',
                 '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/VC/Tools/MSVC/14.44.17.14/Lib/arm64',
                 '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/Windows Kits/10/Lib/10.0.26100/um/arm64',
                 '-Xlinker', '/libpath:/opt/aarch64-pc-windows-msvc/Windows Kits/10/Lib/10.0.26100/ucrt/arm64']

c_winlibs = ['libcmt', 'oldnames', 'kernel32', 'user32', 'gdi32', 'winspool',
             'shell32', 'ole32', 'oleaut32', 'uuid', 'comdlg32', 'advapi32']
```

## Cross-Compilation in Rust

Compared with C/C++, Rust officially provides precompiled standard libraries for different target machines. Therefore, pure Rust dependencies require almost no additional configuration. However, dependencies with external native/FFI components still require a sysroot.

Rustc can produce object files for different CPU architectures by itself, so the key is configuring the linker.

<https://github.com/rust-cross/cargo-xwin>

<https://github.com/rust-cross/cargo-zigbuild>

| ⬇️Target \ Host➡️                    | Windows             | macOS               | Linux               |
| ------------------------------------ | ------------------- | ------------------- | ------------------- |
| Windows (same CPU architecture)      | 🚫                  | cargo-xwin          | cargo-xwin          |
| Windows (different CPU architecture) | MSVC Cross Tool     | cargo-xwin          | cargo-xwin          |
| macOS (same CPU architecture)        | sysroot + LLVM      | 🚫                  | sysroot + LLVM      |
| macOS (different CPU architecture)   | sysroot + LLVM      | LLVM                | sysroot + LLVM      |
| Linux (same CPU architecture)        | cargo-zigbuild      | cargo-zigbuild      | 🚫                  |
| Linux (different CPU architecture)   | cargo-zigbuild      | cargo-zigbuild      | cross GCC           |
| WASM (Browser)                       | wasm-bindgen        | wasm-bindgen        | wasm-bindgen        |
| WASM (WASI)                          | wasi-sdk (optional) | wasi-sdk (optional) | wasi-sdk (optional) |

In actual projects, you need to configure `linker-arg` to specify the sysroot.

## Cross-Compilation in Go

Because Go uses Plan 9 assembly and implements its own syscall mechanism, cross-compilation works out of the box. You only need to specify `GOOS` and `GOARCH`.

However, if there are CGO dependencies, you still need C/C++ cross-compilation tools.

## Cross-Compilation in Zig

Zig bundles LLVM tools and the libc implementations for various systems, so cross-compilation works out of the box.

<https://zig.guide/build-system/cross-compilation/>
