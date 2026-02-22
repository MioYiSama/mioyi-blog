---
title: Arch Linux Installation
tags: [OS]
---

## Download Image

<https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso>

## Hard Drive

```bash
# Partitioning
cfdisk /dev/...

# Formatting
mkswap /dev/...
mkfs.ext4 /dev/...

# Mounting
mount /dev/... /mnt
swapon /dev/...

# The fstab file allows the system to automatically mount specified file systems at startup
genfstab -U /mnt >> /mnt/etc/fstab
```

## Install Packages

```bash
# Update mirror source
reflector --country China --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Install packages
pacstrap /mnt base base-devel linux linux-firmware
```

## Settings

1. Enter System

```bash
arch-chroot /mnt
```

2. Time Zone

```bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
```

3. Localization

```bash
pacman -S nano

nano /etc/locale.gen
# Uncomment en_US.UTF-8 and zh_CN.UTF-8 lines

locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

4. Hostname

```bash
echo "archlinux" > /etc/hostname
```

5. hosts

```bash
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts
```

6. User

```bash
# Set root password
passwd

# Install sudo
pacman -S sudo

# Create user
useradd -m -G wheel -s /bin/bash <username>
passwd <username>

# Configure sudo
EDITOR=nano visudo
# Uncomment %wheel ALL=(ALL:ALL) ALL
```

7. Network

```bash
pacman -S networkmanager
systemctl enable NetworkManager
```

8. Install Desktop Environment

```bash
# Install basic KDE Plasma environment
pacman -S plasma-meta

# Install file management, terminal, compression software
pacman -S dolphin konsole ark

# Install Wayland related packages
pacman -S plasma-workspace

# Install SDDM (KDE recommended display manager)
pacman -S sddm
systemctl enable sddm.service
```

9. Install Drivers

```bash
pacman -S intel-ucode

# Install NVIDIA drivers
pacman -S nvidia nvidia-utils nvidia-settings

# Load NVIDIA drivers
nano /etc/mkinitcpio.conf
# Modify to: MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
mkinitcpio -P
```

## Reboot

```bash
# Exit chroot environment
exit

# Unmount partitions
umount -R /mnt

# Reboot system
reboot
```

## Further Configuration

```bash
# Install basic sound drivers (ALSA)
sudo pacman -S alsa-utils alsa-firmware alsa-plugins
# Sound server
sudo pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

sudo usermod -aG audio $(whoami)

systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service
systemctl --user enable --now wireplumber.service
```