---
title: "交叉编译教程"
tags: [编程语言]
---

“交叉编译”，顾名思义就是两台机器互相编译成对方的可执行文件。换句话说就是在一台电脑上编译出不同操作系统/CPU架构的可执行文件

## 目标

| ⬇️Target \ Host➡️        | Windows | macOS | Linux |
| ---------------------- | ------- | ----- | ----- |
| Windows（相同CPU架构） | 🚫       |       |       |
| Windows（不同CPU架构） |         |       |       |
| macOS（相同CPU架构）   |         | 🚫     |       |
| macOS（不同CPU架构）   |         |       |       |
| Linux（相同CPU架构）   |         |       | 🚫     |
| Linux（不同CPU架构）   |         |       |       |
| WASM (Browser)         |         |       |       |
| WASM (WASI)            |         |       |       |

## 原理

产生一个可执行文件，通常需要如下几步：

1. 将源码编译成特定CPU架构的目标文件（.o）
2. 链接目标文件、语言标准库、操作系统标准库，生成可执行文件

第一步相对简单，只需要编译器支持生成不同CPU架构的目标文件（LLVM、cross GCC、MinGW等）。

第二步则通常需要目标机器的头文件和标准库，也称为sysroot。链接器要能够处理不同的操作系统syscall。除此之外还需要链接器能够识别目标机器的库和生成目标机器的可执行文件（PE、Mach-O、ELF格式）。LLD是其中之一。

## 获取 sysroot

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
> 根据 <https://www.apple.com/legal/sla/docs/xcode.pdf>，在非macOS系统的机器上使用MacOSX SDK属于违规行为

1. 下载XCode：<https://developer.apple.com/download/all/?q=xcode>
2. 编写Dockerfile

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

3. 运行命令（下面的示例里 我把XCode挂载到了/xcode，请根据实际情况指定）

```bash
docker build -t mioyisama/osxcross:latest .

docker run -it --rm -v $(pwd)/xcode:/xcode mioyisama/osxcross:latest

./tools/gen_sdk_package_pbzx.sh /xcode/Xcode_16.4.xip
mv MacOSX*.sdk.tar.bz2 /xcode
```

4. 解压 `MacOSX*.sdk.tar.bz2`

### Linux (GNU)

```Dockerfile
FROM debian:unstable-slim AS sysroot

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update

WORKDIR /workspace

# 让 APT 认为“当前系统什么包都没安装”
RUN touch /tmp/empty-status \
    && apt-get clean \
    && apt-get install -y \
        --download-only \
        --no-install-recommends \
        -o Dir::State::status=/tmp/empty-status \
        libc6-dev linux-libc-dev libstdc++-16-dev

# 把 APT 求解出来的整个依赖闭包全部解压
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

浏览器和WASI不同，没有像其他环境一样的syscall，依赖JS向WASM暴露接口，因此需要胶水代码。

- 对于C/C++，可以使用<https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html>
- 对于Rust，可以使用<https://github.com/wasm-bindgen/wasm-bindgen>

### WASM (WASI)

<https://github.com/WebAssembly/wasi-sdk/releases/latest>

下载 `libclang_rt-??.?+m.tar.gz` 和 `wasi-sysroot-??.?+m.tar.gz` 并解压

## C/C++交叉编译

CMake支持通过CMakeToolchains交叉编译；Meson也类似：<https://mesonbuild.com/Cross-compilation.html>。

| ⬇️Target \ Host➡️        | Windows         | macOS          | Linux                |
| ---------------------- | --------------- | -------------- | -------------------- |
| Windows（相同CPU架构） | 🚫               | sysroot + LLVM | MinGW/sysroot + LLVM |
| Windows（不同CPU架构） | MSVC Cross Tool | sysroot + LLVM | MinGW/sysroot + LLVM |
| macOS（相同CPU架构）   | sysroot + LLVM  | 🚫              | sysroot + LLVM       |
| macOS（不同CPU架构）   | sysroot + LLVM  | LLVM           | sysroot + LLVM       |
| Linux（相同CPU架构）   | sysroot + LLVM  | sysroot + LLVM | 🚫                    |
| Linux（不同CPU架构）   | sysroot + LLVM  | sysroot + LLVM | cross GCC            |
| WASM (Browser)         | emscripten      | emscripten     | emscripten           |
| WASM (WASI)            | LLVM            | LLVM           | LLVM                 |

- CMake配置示例

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

- meson配置示例

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

## Rust交叉编译

Rust相比C/C++，官方提供了不同目标机器的预编译标准库。因此对于纯Rust的依赖，几乎无需额外配置。但是对于有外部native/ffi依赖的，依旧需要sysroot。

Rustc本身就能做到输出不同cpu架构的目标文件，因此关键在于链接器的配置。

<https://github.com/rust-cross/cargo-xwin>

<https://github.com/rust-cross/cargo-zigbuild>

| ⬇️Target \ Host➡️        | Windows          | macOS            | Linux            |
| ---------------------- | ---------------- | ---------------- | ---------------- |
| Windows（相同CPU架构） | 🚫                | cargo-xwin       | cargo-xwin       |
| Windows（不同CPU架构） | MSVC Cross Tool  | cargo-xwin       | cargo-xwin       |
| macOS（相同CPU架构）   | sysroot + LLVM   | 🚫                | sysroot + LLVM   |
| macOS（不同CPU架构）   | sysroot + LLVM   | LLVM             | sysroot + LLVM   |
| Linux（相同CPU架构）   | cargo-zigbuild   | cargo-zigbuild   | 🚫                |
| Linux（不同CPU架构）   | cargo-zigbuild   | cargo-zigbuild   | cross gcc        |
| WASM (Browser)         | wasm-bindgen     | wasm-bindgen     | wasm-bindgen     |
| WASM (WASI)            | wasi-sdk（可选） | wasi-sdk（可选） | wasi-sdk（可选） |

实际项目中需要配置linker-arg指定sysroot

## Go交叉编译

Go由于使用了Plan9汇编并自己实现了syscall机制，因此交叉编译开箱即用。只需指定`GOOS`和`GOARCH`。

但如果存在CGO依赖，则依旧需要C/C++交叉编译的工具。

## Zig交叉编译

Zig本体打包了LLVM工具和各个系统的libc，因此交叉编译开箱即用。

<https://zig.guide/build-system/cross-compilation/>