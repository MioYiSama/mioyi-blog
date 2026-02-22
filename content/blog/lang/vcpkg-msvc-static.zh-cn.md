---
title: C++静态链接
tags: [编程语言]
---

## MSVC

```cmake {filename="CMakeLists.txt"}
set(VCPKG_TARGET_TRIPLET "x64-windows-static")

# ...

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
```

## MinGW

默认情况下需要三个库：

- `libgcc_s_seh-1.dll`
- `libstdc++-6.dll`
- `libwinpthread-1.dll`

前两个库只需要使用 `-static-libgcc` 和 `-static-libstdc++` 这两个选项
第三个库由于其特殊性，需要`-Wl,-Bstatic,--whole-archive -lwinpthread`

```cmake
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive -static-libgcc -static-libstdc++")
```

> [!NOTE]
>
> - `-Wl,`: 将后面的选项传递给链接器（ld）
> - `-Bstatic`: 强制使用静态链接（而非动态链接）
> - `--whole-archive`: 包含整个静态库的所有对象文件，即使某些符号未被引用
>
> winpthread 的特殊性在于它使用了大量隐式初始化机制（构造函数、TLS 回调、静态初始化），这些代码没有被用户代码直接调用，但运行时必须存在，因此需要强制链接整个库。
