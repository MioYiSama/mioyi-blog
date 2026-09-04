---
title: 用 Arch 的方式安装 Debian
tags: [操作系统]
---

## 前言

我用过一些Linux发行版，给我的感受是或多或少都有一些问题。Arch容易滚挂；Debian太毛坯；Ubuntu太bloated；Fedora没有apt生态；别的发行版要么太冷门要么不适合桌面用户场景。有没有办法结合Arch的干净清爽+滚动更新和Debian的庞大生态+稳定？因此我打算用命令行的方式装Debian Testing来实现这点。

> 以下教程仅针对 PC（无WIFI） + 双硬盘 + Intel CPU + 单NV显卡 + KDE + 音频走显示器 + UEFI + Secure Boot

## 前置步骤

1. 下载Debian Live Standard镜像（https://cdimage.debian.org/cdimage/weekly-live-builds/amd64/iso-hybrid/）
2. 启动镜像后选择Live System
3. 开始敲命令

```bash
sudo su

# 调大终端字体（可选）
setfont /usr/share/consolefonts/Lat15-TerminusBold32x16.psf.gz

apt update
# dosfstools提供mkfs.fat
apt install dosfstools btrfs-progs debootstrap arch-install-scripts
```

## 分区 + bootstrap

```bash
cfdisk /dev/nvme1n1 # 512M EFI System + ??G Linux filesystem

# 格式化
mkfs.fat -F32 /dev/nvme1n1p1
mkfs.btrfs -f /dev/nvme1n1p2

# 创建子卷
mount /dev/nvme1n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
umount /mnt

# 逐个挂载
mount -o subvol=@,compress=zstd,noatime /dev/nvme1n1p2 /mnt
mkdir -p /mnt/{home,var/log,.snapshots,swap,boot/efi}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme1n1p2 /mnt/home
mount -o subvol=@var_log,compress=zstd,noatime /dev/nvme1n1p2 /mnt/var/log
mount -o subvol=@snapshots,compress=zstd,noatime /dev/nvme1n1p2 /mnt/.snapshots
mount -o subvol=@swap,noatime /dev/nvme1n1p2 /mnt/swap
mount /dev/nvme1n1p1 /mnt/boot/efi
btrfs filesystem mkswapfile --size 32G /mnt/swap/swapfile
swapon /mnt/swap/swapfile # swapon --show检查

# 安装系统
# 注：minbase不包含debian-archive-keyring，需要额外安装
debootstrap \
    --variant=minbase \
    --components=main,contrib,non-free,non-free-firmware \
    --include=ca-certificates,debian-archive-keyring \
    testing \
    /mnt \
    https://deb.debian.org/debian

genfstab -U /mnt > /mnt/etc/fstab # /mnt/etc/fstab检查
arch-chroot /mnt
```

## 装包

```bash
apt modernize-sources
apt update
apt install \
  linux-image-amd64 \
  initramfs-tools \
  btrfs-progs \
  grub-efi-amd64 efibootmgr \ # Boot
  network-manager locales tzdata \ # 网络 地区 时区
  sudo curl wget adduser \
  intel-microcode firmware-linux # 微码 驱动
```

## 基本配置

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
# 包含 en_US.UTF-8 UTF-8 + zh_CN.UTF-8 UTF-8
# 默认 en_US.UTF-8

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

## KDE桌面 + NV显卡驱动

```bash
# 元包体积对比：kde-plasma-desktop < kde-standard < task-kde-desktop < kde-full
apt install kde-standard sddm
systemctl enable sddm
systemctl set-default graphical.target

# 快速排错
# apt install libglib2.0-bin gsettings-desktop-schemas # 软件修改不了网络代理
# apt install xdg-desktop-portal-kde # 软件读不到深色模式
# apt install kscreen kinfocenter # 系统设置没有显示器设置、关于

# 官方仓库的NV驱动过于老旧，需要使用NV官方仓库
wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb
apt install ./cuda-keyring_1.1-1_all.deb
apt update
apt install linux-headers-amd64 dkms nvidia-open mokutil
dkms status # 检查

dkms generate_mok
mokutil --import /var/lib/dkms/mok.pub # 随便设置密码
# 重启后会出现蓝色的 MOK Manager界面
# 选择Enroll MOK
# → Continue
# → Yes
# → 输入刚才设置的一次性密码
# → Reboot

update-initramfs -u -k all
update-grub # 保险起见
exit
swapoff /mnt/swap/swapfile
umount -R /mnt
reboot
```

## 重启后

```bash
# 安装Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb
```

## grub启动Windows

```bash
sudo nano /etc/default/grub # 确保GRUB_DISABLE_OS_PROBER=false
sudo os-prober # 若没有windows则进行下面的手动修改
blkid /dev/nvme0n1p1 # 获取UUID
sudo nano /etc/grub.d/40_custom # 见下面
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

## 安装snapper（可选）管理btrfs快照

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
