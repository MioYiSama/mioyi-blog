---
title: 双系统
tags: [操作系统]
---

## 原理

1. Boot

不论启动什么操作系统，都需要一个Boot文件和一个Boot Loader。

前者告诉Boot Loader系统的组成部分，以及怎么启动系统；

后者加载Boot文件，指挥硬件启动系统。

2. 系统

每一个系统，都至少可以分为两个部分：Boot文件和主空间（Windows的`C:`或者Linux的`/`）。

3. 双系统

为了配置双系统，必然需要一个Boot Loader、两个OS的Boot文件和两个OS的主空间。

对于Boot Loader，为了能够同时启动Linux和Windows，我们选择[rEFInd](https://sourceforge.net/projects/refind/)

4. Ventoy

如果说Boot Loader是为了启动系统，Ventoy就是为了启动镜像。

## 准备

搞一个U盘，安装[Ventoy](https://www.ventoy.net/cn/download.html)，并且存有Windows、Linux、[微PE](https://www.wepe.com.cn/download.html)镜像。（为此U盘至少需要8G）

## 安装 rEFInd 和 Windows

> 不安装Windows可跳过2，3，6

1. 进入BIOS，设置为U盘启动，保存重启，进入Ventoy，启动微PE。
2. 打开分区工具（DiskGenius），创建1GB EFI FAT32分区（存放BootLoader和Windows的文件），以及若干GB存放Windows系统，剩余空间留下备用
3. 打开WinNTSetup，安装Windows镜像，安装完不要重启

> 后续操作可查看[rEFInd，可能是颜值最高的多系统、硬盘引导神器](https://www.bilibili.com/video/BV1714y1c78z)

4. 打开DiskGenius，往EFI分区中的EFI文件夹中添加refind主文件夹下的refind文件夹
5. 添加UEFI启动项，把refind.efi文件添加成启动项，并设置为第一个启动
6. 重启，自行配置Windows

## 安装 Linux

1. 用Ventoy启动linux镜像

> 后续操作可查看[Arch Linux 安装](/posts/os/install-arch.html)

2. 手动分区，若干GB给swap，剩余GB用EXT4格式化并挂载到根目录
3. 继续安装和配置
