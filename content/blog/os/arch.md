---
title: Arch Linux Installation
tags: [OS]
---

> [!NOTE]
> KDE (Wayland) + Intel + NVIDIA

> [!NOTE]
> Does not include grub installation tutorial; uses pre-installed rEFInd to boot the system

```bash
# Partitioning
cfdisk /dev/nvme0n1
mkswap /dev/nvme0n1p3
mkfs.ext4 /dev/nvme0n1p4
mount /dev/nvme0n1p4 /mnt
swapon /dev/nvme0n1p3

# Installation
reflector --latest 5 --sort rate --country China --save /etc/pacman.d/mirrorlist
pacstrap -K /mnt base linux linux-firmware intel-ucode networkmanager nano sudo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Timezone and Language
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
sudo nano /etc/locale.gen # Uncomment en_US.UTF-8 UTF-8
locale-gen
nano /etc/locale.conf # Add LANG=en_US.UTF-8

nano /etc/hostname
systemctl enable NetworkManager.service
passwd # root password
useradd -m -G wheel mioyi
passwd mioyi
nano /etc/sudoers # Uncomment the %wheel ALL=(ALL:ALL) line

# KDE
pacman -S plasma-meta konsole dolphin sddm
systemctl enable sddm.service

# NVIDIA Drivers
pacman -S nvidia nvidia-dkms nvidia-utils linux-headers
nano /etc/mkinitcpio.conf # Modify to MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
mkinitcpio -P

# Finishing up
exit
umount -R /mnt
reboot

# Chinese Fonts
sudo pacman -S noto-fonts-cjk
# Change system fonts in System Settings

# Input Method
sudo pacman -S fcitx5-im fcitx5-chinese-addons
# System Settings → Keyboard → Virtual Keyboard, select Fcitx 5
# System Settings → Input Method, add "Pinyin"
```
