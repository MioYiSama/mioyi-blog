---
title: "C/C++ 中的可移植性问题"
tags: [编程语言]
---

## 1. **数据类型大小**

### 问题
整数和指针大小在不同平台上有所不同。

```c
// ❌ 非可移植的假设
int x = ptr;  // 假设指针能放入 int（在 64 位系统上失败）
long l = 5L;  // Windows 64 上 long 是 32 位，Unix 上是 64 位

// ✅ 可移植解决方案
#include <stdint.h>
int32_t x;      // 精确 32 位
uint64_t y;     // 精确 64 位
intptr_t ptr_i; // 能容纳指针的整数
size_t sz;      // 用于大小
```

## 2. **字节序（Endianness）**

### 问题
不同 CPU 以不同方式存储多字节值。

```c
// ❌ 非可移植
union {
    uint32_t i;
    uint8_t bytes[4];
} data;
data.i = 0x12345678;
// bytes[0] 是 0x78（小端）或 0x12（大端）

// ✅ 可移植字节提取
uint32_t value = 0x12345678;
uint8_t byte0 = (value >> 24) & 0xFF;  // 始终为 0x12
uint8_t byte3 = value & 0xFF;           // 始终为 0x78

// ✅ 网络字节序转换
#include <arpa/inet.h>  // Unix
uint32_t net = htonl(host_value);  // 主机序到网络序（大端）
uint32_t host = ntohl(net_value);  // 网络序到主机序
```

## 3. **编译器特定扩展**

```c
// ❌ 非可移植（GCC/Clang 特定）
int array[0];              // 零长度数组
typeof(x) y;               // typeof 操作符
__attribute__((packed));   // 属性

// ✅ 可移植替代方案
#ifdef __GNUC__
    __attribute__((packed))
#elif defined(_MSC_VER)
    __declspec(align(1))
#endif

// 使用标准
#include <stdalign.h>  // C11
alignas(16) int x;
```

## 4. **操作系统差异**

### 文件路径
```c
// ❌ 平台特定
#define PATH "C:\\Users\\file.txt"     // 仅 Windows
#define PATH "/home/user/file.txt"     // 仅 Unix

// ✅ 运行时构造
#ifdef _WIN32
    const char *sep = "\\";
#else
    const char *sep = "/";
#endif
```

### 系统 API
```c
// ❌ 平台特定 API
#include <windows.h>
HANDLE h = CreateFile(...);  // 仅 Windows

#include <unistd.h>
int fd = open(...);          // 仅 POSIX

// ✅ 使用抽象或跨平台库
// 标准 C FILE* 或 C++ fstream
FILE *f = fopen("file.txt", "r");
```

## 5. **字符集和编码**

```c
// ❌ 假设 ASCII
char c = 'A';
if (c == 65) { ... }  // 脆弱

// ✅ 独立于字符的编码
if (c == 'A') { ... }

// 用于 Unicode 的宽字符
#include <wchar.h>
wchar_t wstr[] = L"Hello 世界";
```

## 6. **结构体填充和对齐**

```c
// ❌ 假设无填充
struct Data {
    char c;    // 1 字节
    int i;     // 4 字节
};
// 大小可能为 5、8 或其他，取决于平台！

// ✅ 注意填充
size_t size = sizeof(struct Data);  // 使用 sizeof，不要假设

// 强制打包（谨慎使用）
#pragma pack(push, 1)
struct Packed {
    char c;
    int i;
} __attribute__((packed));  // GCC
#pragma pack(pop)
```

## 7. **指针问题**

```c
// ❌ 指针/整数混淆
int *p = (int *)0x1000;  // 假设地址空间
int i = (int)p;          // 64 位上截断

// ✅ 正确的指针处理
#include <stdint.h>
uintptr_t addr = (uintptr_t)p;  // 安全转换

// ❌ 指针算术假设
char *p1 = malloc(10);
char *p2 = malloc(10);
ptrdiff_t diff = p1 - p2;  // 如果不是同一分配，则未定义！
```

## 8. **有符号 vs 无符号**

```c
// ❌ 隐式符号问题
char c = 200;  // 实现定义：signed char 或 unsigned char？
if (c > 0) { ... }  // 如果 char 是有符号的，可能为 false！

// ✅ 显式符号性
unsigned char uc = 200;
signed char sc = 100;

// ❌ 危险比较
int i = -1;
unsigned int u = 1;
if (i < u) { ... }  // 错误！i 被转换为无符号
```

## 9. **未定义和未指定行为**

```c
// ❌ 未定义行为（在不同编译器上变化）
int i = 0;
i = i++;              // 未定义行为
int x = (1 << 31);    // 对有符号 int 未定义
int *p = NULL;
*p = 5;               // 未定义

// 未指定：求值顺序
f() + g();            // f() 和 g() 顺序未保证
printf("%d %d", i++, i++);  // 未指定的顺序
```

## 10. **浮点数可移植性**

```c
// ❌ 假设 IEEE 754
float f = 0.1;
if (f == 0.1) { ... }  // 可能因精度而失败

// ✅ Epsilon 比较
#include <float.h>
#include <math.h>
if (fabs(f - 0.1) < FLT_EPSILON) { ... }

// 可移植检查特殊值
if (isnan(x)) { ... }
if (isinf(x)) { ... }
```

## 11. **行结束符**

```c
// ❌ 文本模式因平台而异
FILE *f = fopen("file.txt", "r");  // Unix 上 \n，Windows 上 \r\n

// ✅ 二进制模式以保持一致性
FILE *f = fopen("file.txt", "rb");  // 跨平台一致

// 或显式处理
while ((c = fgetc(f)) != EOF) {
    if (c == '\r' || c == '\n') { ... }
}
```

## 12. **预处理器差异**

```c
// ❌ 非可移植的预定义宏
#ifdef WIN32  // 某些编译器使用 _WIN32

// ✅ 检查多个变体
#if defined(_WIN32) || defined(_WIN64) || defined(__WINDOWS__)
    // Windows 代码
#elif defined(__linux__)
    // Linux 代码
#elif defined(__APPLE__)
    // macOS 代码
#endif
```

## 13. **标准库变体**

```c
// ❌ 平台特定函数
char *str = strdup(s);   // 非 C 标准（POSIX）
strlcpy(dst, src, n);    // BSD，非通用

// ✅ 标准替代方案
char *str = malloc(strlen(s) + 1);
if (str) strcpy(str, s);

// 或提供回退
#ifndef HAVE_STRDUP
char *strdup(const char *s) {
    char *p = malloc(strlen(s) + 1);
    return p ? strcpy(p, s) : NULL;
}
#endif
```

## 14. **整数提升和转换**

```c
// ❌ 隐式转换
uint8_t a = 200, b = 100;
uint8_t c = a + b;  // 溢出！提升为 int，然后截断

// ✅ 显式类型
uint8_t c = (uint8_t)((unsigned)a + b);
// 或使用更宽类型
unsigned int result = (unsigned)a + b;
```

## 15. **调用约定**

```c
// ❌ 假设特定调用约定
void __cdecl func();     // MSVC 特定
void __stdcall func2();  // Windows 特定

// ✅ 使用标准声明或抽象
void func(void);

// 对于 DLL，使用宏
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT __attribute__((visibility("default")))
#endif
```

## **可移植代码的最佳实践**

### 1. **使用标准头文件**
```c
#include <stdint.h>   // 固定宽度整数
#include <stddef.h>   // size_t, ptrdiff_t
#include <stdbool.h>  // bool 类型（C99）
#include <limits.h>   // INT_MAX 等
```

### 2. **功能测试**
```c
#if __STDC_VERSION__ >= 201112L
    // C11 功能可用
#endif

#ifdef __cplusplus
    // C++ 代码
#else
    // C 代码
#endif
```

### 3. **使用 sizeof 计算大小**
```c
// ❌ 切勿硬编码大小
int array[10];
memset(array, 0, 40);  // 在某些平台上错误！

// ✅ 始终使用 sizeof
memset(array, 0, sizeof(array));
```

### 4. **配置头文件**
```c
// config.h（由构建系统生成）
#ifdef HAVE_UNISTD_H
    #include <unistd.h>
#endif

#ifdef HAVE_SYS_TYPES_H
    #include <sys/types.h>
#endif
```

### 5. **跨平台库**
- 使用如 **Boost**（C++）、**GLib**、**APR** 等库
- 抽象操作系统特定功能
- 使用 CMake 实现构建可移植性

---

**关键要点**：编写符合标准（C99/C11/C++11/14/17/20）的代码，避免对实现细节的假设，在多个平台上测试，并为操作系统特定功能使用抽象层。