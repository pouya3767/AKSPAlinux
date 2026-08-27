#!/usr/bin/env bash
set -euo pipefail

TARGET_DISK="${1:?یک دیسک هدف بده، مثال: /dev/sda}"
SRC="/usr/local/share/akspa-installer"

echo "[akspa-install] پارتیشن‌بندی ${TARGET_DISK}..."
parted -s "$TARGET_DISK" -- mklabel gpt
parted -s "$TARGET_DISK" -- mkpart ESP fat32 1MiB 513MiB
parted -s "$TARGET_DISK" -- set 1 esp on
parted -s "$TARGET_DISK" -- mkpart rootA ext4 513MiB 15.5GiB
parted -s "$TARGET_DISK" -- mkpart rootB ext4 15.5GiB 30.5GiB
parted -s "$TARGET_DISK" -- mkpart DATA ext4 30.5GiB 100%

mkfs.fat -F32 -n ESP   "${TARGET_DISK}1"
mkfs.ext4 -L rootA     "${TARGET_DISK}2"
mkfs.ext4 -L rootB     "${TARGET_DISK}3"
mkfs.ext4 -L DATA      "${TARGET_DISK}4"

echo "[akspa-install] mount کردن..."
mount "${TARGET_DISK}2" /mnt
mkdir -p /mnt/boot /mnt/home
mount "${TARGET_DISK}1" /mnt/boot
mount "${TARGET_DISK}4" /mnt/home

echo "[akspa-install] نصب پایه سیستم..."
pacstrap /mnt base linux linux-firmware plasma-desktop plasma-workspace \
    qt6-wayland xorg-xwayland sddm seatd networkmanager

genfstab -U /mnt >> /mnt/etc/fstab

echo "[akspa-install] کپی فایل‌های A/B روی تارگت..."
install -Dm755 "$SRC/ab-snapshot.sh"   /mnt/usr/local/bin/ab-snapshot.sh
install -Dm755 "$SRC/ab-mark-good.sh"  /mnt/usr/local/bin/ab-mark-good.sh
install -Dm644 "$SRC/95-ab-snapshot.hook" /mnt/etc/pacman.d/hooks/95-ab-snapshot.hook
install -Dm644 "$SRC/ab-boot-success.service" /mnt/etc/systemd/system/ab-boot-success.service

cat > /mnt/etc/ab-release <<EOF
SLOT=A
PARTNER=B
PARTNER_LABEL=rootB
EOF

echo "[akspa-install] نصب bootloader..."
arch-chroot /mnt bootctl install
mkdir -p /mnt/boot/loader/entries

cat > /mnt/boot/loader/entries/akspa-current.conf <<EOF
title   AKSPALinux (فعال)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=LABEL=rootA rw quiet
EOF

cat > /mnt/boot/loader/entries/akspa-rollback.conf <<EOF
title   AKSPALinux (Rollback)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=LABEL=rootB rw quiet
EOF

cat > /mnt/boot/loader/loader.conf <<EOF
default akspa-current.conf
timeout 3
console-mode max
EOF

echo "[akspa-install] فعال‌سازی سرویس‌ها..."
arch-chroot /mnt systemctl enable sddm.service
arch-chroot /mnt systemctl enable seatd.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable ab-boot-success.service

echo "[akspa-install] تمام شد. حالا می‌تونی reboot کنی."
