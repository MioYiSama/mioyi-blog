---
title: "使用C++模块和import std"
tags: [编程语言]
---

## macOS + Clang

> [!WARNING]
> `Clang` 版本至少为 19

1. 安装工具

```shell
xcode-select --install
brew install llvm cmake ninja
```

> [!NOTE]
>
> - AppleClang 版本较老，为了能够用上最新的特性，建议使用 Homebrew 提供的 LLVM。
> - `import std` 特性需要使用Ninja

2. 配置 CMake 命令行

- 生成器：建议使用最新的Multi Config，可以将Debug和Release配置生成在同一个文件夹中

```shell
-G "Ninja Multi-Config"
```

- 系统标准库（macOS专有配置）

```shell
-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

> [!NOTE]
>
> - 可使用 `xcrun --sdk macosx --show-sdk-path` 查看具体路径
> - 建议使用系统提供的标准库，不建议链接到Homebrew LLVM提供的`libc++` `libunwind`。

- `std` 模块的JSON文件

```shell
-DCMAKE_CXX_STDLIB_MODULES_JSON=/opt/homebrew/opt/llvm/lib/c++/libc++.modules.json
```

> [!NOTE]
> 可使用 `find /opt/homebrew -name "libc++.modules.json" -maxdepth 10` 寻找具体路径，然后重写为 `/opt/homebrew/opt/llvm/...`

3. 配置 `CMakeLists.txt`

```cmake {filename="CMakeLists.txt"}
cmake_minimum_required(VERSION 4.2)
# 必须在project前设置。具体的UUID值随CMake版本变化。请查阅：
# https://github.com/Kitware/CMake/blob/版本号/Help/dev/experimental.rst#c-import-std-support
#（版本号示例：v4.2.3）
set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
project(example LANGUAGES CXX)

add_executable(example)
# 配置C++23标准
target_compile_features(example PRIVATE cxx_std_23)
# 启用import std，禁用非标准的扩展
set_target_properties(example PROPERTIES
    CXX_MODULE_STD ON
    CMAKE_CXX_EXTENSIONS OFF
)

# 添加普通源文件
target_sources(example PRIVATE main.cpp)
# 添加模块文件
target_sources(example PRIVATE
    FILE_SET CXX_MODULES FILES foo.cppm
)
```

## Linux + gcc

> [!WARNING]
> `gcc` 版本至少为15

> [!NOTE]
> 未提及的操作和macOS完全相同

1. 安装工具

```shell
sudo apt install g++-15 cmake ninja-build
```

```shell
sudo dnf install gcc-c++ cmake ninja-build
```

2. `std` 模块的JSON文件：使用下面的命令获取

```shell
g++ -print-file-name=libstdc++.modules.json
```

3. 修改CMakeLists.txt

```cmake
target_compile_options(example PRIVATE -fmodules)
```

## Windows + MSVC

> [!WARNING]
> `MSVC` 版本至少为 14.36（等同于 Visual Studio 2022 v17.6）

具体操作基本同macOS，但是不需要提供 `CMAKE_CXX_STDLIB_MODULES_JSON`
