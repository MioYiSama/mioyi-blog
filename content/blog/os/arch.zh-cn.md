---
title: Arch Linux 安装
tags: [操作系统]
---

> [!NOTE]
> KDE (Wayland) + Intel + NVIDIA

> [!NOTE]
> 不含grub安装教程，使用预先安装的rEFInd引导系统

```bash
# 分区
cfdisk /dev/nvme0n1
mkswap /dev/nvme0n1p3
mkfs.ext4 /dev/nvme0n1p4
mount /dev/nvme0n1p4 /mnt
swapon /dev/nvme0n1p3

# 安装
reflector --latest 5 --sort rate --country China --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt base linux linux-firmware intel-ucode networkmanager nano sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# 时区和语言
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
sudo nano /etc/locale.gen # 取消注释 en_US.UTF-8 UTF-8
locale-gen
nano /etc/locale.conf # 添加 LANG=en_US.UTF-8

nano /etc/hostname
systemctl enable NetworkManager.service
passwd # root 密码
useradd -m -G wheel mioyi
passwd mioyi
nano /etc/sudoers # 取消注释 %wheel ALL=(ALL:ALL) 行

# KDE
pacman -S plasma-meta konsole dolphin sddm
systemctl enable sddm.service

# NVIDIA 驱动
pacman -S nvidia nvidia-dkms nvidia-utils linux-headers
nano /etc/mkinitcpio.conf # 修改为 MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
mkinitcpio -P

# 收尾
exit
umount -R /mnt
reboot

# 中文字体
sudo pacman -S noto-fonts-cjk
# 系统设置里修改系统字体

# 输入法
sudo pacman -S fcitx5-im fcitx5-chinese-addons
# System Settings → Keyboard → Virtual Keyboard，选择 Fcitx 5
# System Settings → Input Method 添加“Pinyin”
```
