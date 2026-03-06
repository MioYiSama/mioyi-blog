---
title: "Use C++ Modules and import std"
tags: [programming-language]
---

## macOS + Clang

> [!WARNING]
> `Clang` version must be **at least 19**.

1. Install tools

```shell
xcode-select --install
brew install llvm cmake ninja
```

> [!NOTE]
>
> - The AppleClang version is relatively old. To use the latest features, it is recommended to use the LLVM provided by Homebrew.
> - The `import std` feature requires Ninja.

2. Configure the CMake command line

- Generator: It is recommended to use the latest Multi-Config generator so that Debug and Release configurations can be generated in the same folder.

```shell
-G "Ninja Multi-Config"
```

- System standard library (macOS-specific configuration)

```shell
-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

> [!NOTE]
>
> - You can use `xcrun --sdk macosx --show-sdk-path` to view the exact path.
> - It is recommended to use the system-provided standard library rather than linking to the `libc++` and `libunwind` provided by Homebrew LLVM.

- JSON file for the `std` module

```shell
-DCMAKE_CXX_STDLIB_MODULES_JSON=/opt/homebrew/opt/llvm/lib/c++/libc++.modules.json
```

> [!NOTE]
> You can locate the specific path using
> `find /opt/homebrew -name "libc++.modules.json" -maxdepth 10`,
> then rewrite it as `/opt/homebrew/opt/llvm/...`.

3. Configure `CMakeLists.txt`

```cmake {filename="CMakeLists.txt"}
cmake_minimum_required(VERSION 4.2)
# Must be set before project(). The specific UUID value changes with the CMake version.
# See:
# https://github.com/Kitware/CMake/blob/<version>/Help/dev/experimental.rst#c-import-std-support
# (Example version: v4.2.3)
set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
project(example LANGUAGES CXX)

add_executable(example)
# Configure C++23 standard
target_compile_features(example PRIVATE cxx_std_23)
# Enable import std and disable non-standard extensions
set_target_properties(example PROPERTIES
    CXX_MODULE_STD ON
    CMAKE_CXX_EXTENSIONS OFF
)

# Add regular source files
target_sources(example PRIVATE main.cpp)
# Add module files
target_sources(example PRIVATE
    FILE_SET CXX_MODULES FILES foo.cppm
)
```

---

## Linux + gcc

> [!WARNING]
> `gcc` version must be **at least 15**.

> [!NOTE]
> Operations not mentioned are exactly the same as on macOS.

1. Install tools

```shell
sudo apt install g++-15 cmake ninja-build
```

```shell
sudo dnf install gcc-c++ cmake ninja-build
```

2. JSON file for the `std` module: obtain it with the following command

```shell
g++ -print-file-name=libstdc++.modules.json
```

3. Modify `CMakeLists.txt`

```cmake
target_compile_options(example PRIVATE -fmodules)
```

---

## Windows + MSVC

> [!WARNING]
> `MSVC` version must be **at least 14.36** (equivalent to Visual Studio 2022 v17.6).

The steps are basically the same as macOS, but **you do not need to provide `CMAKE_CXX_STDLIB_MODULES_JSON`**.
