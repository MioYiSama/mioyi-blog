---
title: Installing Debian the Arch Way
tags: [OS]
---

## Preface

I've used a few Linux distros, and each of them has given me some degree of trouble. Arch breaks easily on rolling updates; Debian is too barebones; Ubuntu is too bloated; Fedora lacks the apt ecosystem; and the remaining distros are either too obscure or not suited for desktop use. Is there a way to combine Arch's cleanliness and rolling releases with Debian's massive ecosystem and stability? So I decided to install Debian Testing from the command line to achieve that.

> The following tutorial only applies to: PC (no WiFi) + dual disks + Intel CPU + single NVIDIA GPU + KDE + audio over the display + UEFI + Secure Boot.

## Preliminary Steps

1. Download the Debian Live Standard image (https://cdimage.debian.org/cdimage/weekly-live-builds/amd64/iso-hybrid/)
2. Boot the image and select Live System
3. Start typing commands

```bash
sudo su

# Enlarge the terminal font (optional)
setfont /usr/share/consolefonts/Lat15-TerminusBold32x16.psf.gz

apt update
# dosfstools provides mkfs.fat
apt install dosfstools btrfs-progs debootstrap arch-install-scripts
```

## Partitioning + Bootstrap

```bash
cfdisk /dev/nvme1n1 # 512M EFI System + ??G Linux filesystem

# Format
mkfs.fat -F32 /dev/nvme1n1p1
mkfs.btrfs -f /dev/nvme1n1p2

# Create subvolumes
mount /dev/nvme1n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
umount /mnt

# Mount them one by one
mount -o subvol=@,compress=zstd,noatime /dev/nvme1n1p2 /mnt
mkdir -p /mnt/{home,var/log,.snapshots,swap,boot/efi}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme1n1p2 /mnt/home
mount -o subvol=@var_log,compress=zstd,noatime /dev/nvme1n1p2 /mnt/var/log
mount -o subvol=@snapshots,compress=zstd,noatime /dev/nvme1n1p2 /mnt/.snapshots
mount -o subvol=@swap,noatime /dev/nvme1n1p2 /mnt/swap
mount /dev/nvme1n1p1 /mnt/boot/efi
btrfs filesystem mkswapfile --size 32G /mnt/swap/swapfile
swapon /mnt/swap/swapfile # check with swapon --show

# Install the system
# Note: minbase does not include debian-archive-keyring, so it needs to be installed explicitly
debootstrap \
    --variant=minbase \
    --components=main,contrib,non-free,non-free-firmware \
    --include=ca-certificates,debian-archive-keyring \
    testing \
    /mnt \
    https://deb.debian.org/debian

genfstab -U /mnt > /mnt/etc/fstab # check /mnt/etc/fstab
arch-chroot /mnt
```

## Installing Packages

```bash
apt modernize-sources
apt update
apt install \
  linux-image-amd64 \
  initramfs-tools \
  btrfs-progs \
  grub-efi-amd64 efibootmgr \ # Boot
  network-manager locales tzdata \ # Network, locale, timezone
  sudo curl wget adduser \
  intel-microcode firmware-linux # Microcode and drivers
```

## Basic Configuration

```bash
echo mioyi-pc > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1 localhost
127.0.1.1 mioyi-pc
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure tzdata
dpkg-reconfigure locales
# Include en_US.UTF-8 UTF-8 + zh_CN.UTF-8 UTF-8
# Default: en_US.UTF-8

passwd
adduser mioyi
usermod -aG sudo mioyi

systemctl enable NetworkManager

grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=Debian
update-grub
```

## KDE Desktop + NVIDIA Driver

```bash
# Meta-package size comparison: kde-plasma-desktop < kde-standard < task-kde-desktop < kde-full
apt install kde-standard sddm
systemctl enable sddm
systemctl set-default graphical.target

# Quick troubleshooting
# apt install libglib2.0-bin gsettings-desktop-schemas # Apps can't change the network proxy
# apt install xdg-desktop-portal-kde # Apps can't read dark mode
# apt install kscreen kinfocenter # No display settings or "About" page in System Settings

# The NVIDIA driver in the official repos is too old, so use NVIDIA's official repo
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
apt install ./cuda-keyring_1.1-1_all.deb
apt update
apt install linux-headers-amd64 dkms nvidia-open mokutil
dkms status # check

dkms generate_mok
mokutil --import /var/lib/dkms/mok.pub # Set any password you like
# After rebooting, a blue MOK Manager screen will appear
# Choose Enroll MOK
# → Continue
# → Yes
# → Enter the one-time password you just set
# → Reboot

update-initramfs -u -k all
update-grub # just to be safe
exit
swapoff /mnt/swap/swapfile
umount -R /mnt
reboot
```

## After Reboot

```bash
# Install Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb
```

## Booting Windows from GRUB

```bash
sudo nano /etc/default/grub # make sure GRUB_DISABLE_OS_PROBER=false
sudo os-prober # if Windows is not detected, do the manual tweak below
blkid /dev/nvme0n1p1 # get the UUID
sudo nano /etc/grub.d/40_custom # see below
sudo update-grub
```

```text
menuentry "Windows Boot Manager" {
    insmod part_msdos
    insmod fat
    insmod chain

    search --no-floppy --fs-uuid --set=root <UUID>
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
```

## Installing snapper (Optional) to Manage Btrfs Snapshots

```bash
sudo apt install snapper
sudo umount /.snapshots
sudo rmdir /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount /.snapshots
sudo snapper -c root list
```
