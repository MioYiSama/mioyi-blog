---
title: Dual Boot
tags: [OS]
---

## How it works

1. Booting

No matter what operating system is being started, a Boot file and a Boot Loader are required.

The former tells the Boot Loader about the system components and how to start the system;

The latter loads the Boot file and directs the hardware to start the system.

2. System

Every system can be divided into at least two parts: the Boot file and the main space (`C:` for Windows or `/` for Linux).

3. Dual Boot

To configure a dual boot setup, it is necessary to have one Boot Loader, the Boot files for two OSs, and the main spaces for two OSs.

For the Boot Loader, to be able to start both Linux and Windows simultaneously, we choose [rEFInd](https://sourceforge.net/projects/refind/).

4. Ventoy

If the Boot Loader is for starting systems, Ventoy is for starting images.

## Preparation

Get a USB flash drive, install [Ventoy](https://www.ventoy.net/en/download.html), and store Windows, Linux, and [WePE](https://www.wepe.com.cn/download.html) images. (The USB drive needs at least 8GB for this).

## Install rEFInd and Windows

> Skip steps 2, 3, and 6 if you are not installing Windows.

1. Enter BIOS, set it to boot from the USB drive, save and restart, enter Ventoy, and start WePE.
2. Open the partitioning tool (DiskGenius), create a 1GB EFI FAT32 partition (to store BootLoader and Windows files), and several GBs to store the Windows system, leaving the remaining space as spare.
3. Open WinNTSetup, install the Windows image, and do not restart after installation.

> For subsequent operations, you can refer to [rEFInd, perhaps the highest-looking multi-system, hard drive boot artifact](https://www.bilibili.com/video/BV1714y1c78z)

4. Open DiskGenius, and add the `refind` folder from the main rEFInd directory into the `EFI` folder within the EFI partition.
5. Add a UEFI boot entry, add the `refind.efi` file as a boot entry, and set it as the first priority.
6. Restart and configure Windows itself.

## Install Linux

1. Boot the Linux image using Ventoy.

> For subsequent operations, you can refer to [Arch Linux Installation](/posts/os/install-arch.html)

2. Partition manually, allocate several GBs to swap, and use the remaining GBs to format with EXT4 and mount to the root directory.
3. Continue installation and configuration.
