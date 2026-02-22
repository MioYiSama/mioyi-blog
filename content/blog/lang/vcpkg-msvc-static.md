---
title: C++ static linking
tags: [programming-language]
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

> [!NOTE]
> WinLibs POSIX threads + UCRT

By default, three libraries are required:

- `libgcc_s_seh-1.dll`
- `libstdc++-6.dll`
- `libwinpthread-1.dll`

The first two libraries only require the use of the `-static-libgcc` and `-static-libstdc++` options.
The third library, due to its particularity, requires `-Wl,-Bstatic,--whole-archive -lwinpthread`.

```cmake
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive -static-libgcc -static-libstdc++")
```

> [!NOTE]
>
> - `-Wl,`: Passes the following options to the linker (ld).
> - `-Bstatic`: Forces the use of static linking (instead of dynamic linking).
> - `--whole-archive`: Includes all object files from the entire static library, even if some symbols are not referenced.
>
> The particularity of winpthread lies in its use of numerous implicit initialization mechanisms (constructors, TLS callbacks, static initialization). This code is not directly called by user code but must exist at runtime, which is why the entire library must be forcibly linked.
