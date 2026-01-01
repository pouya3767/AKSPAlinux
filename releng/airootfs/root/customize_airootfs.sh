#!/bin/bash
set -e

echo "==> AKSPAlinux customize_airootfs.sh started"

# --------------------------------------------------
# Pacman keyring (required for Chaotic-AUR)
# --------------------------------------------------
pacman-key --init
pacman-key --populate archlinux chaotic

# --------------------------------------------------
# Locale
# --------------------------------------------------
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --------------------------------------------------
# Timezone
# --------------------------------------------------
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# --------------------------------------------------
# Create live user
# --------------------------------------------------
# useradd -m -G wheel,video,audio,input,seat liveuser
# echo "liveuser:live" | chpasswd

# Passwordless sudo for live user
echo "liveuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser
chmod 0440 /etc/sudoers.d/liveuser

# --------------------------------------------------
# Enable required services
# --------------------------------------------------

# Seat management (required for Hyprland)
systemctl enable seatd.service

# Network
systemctl enable NetworkManager.service

# SSH (optional but useful)
systemctl enable sshd.service

# --------------------------------------------------
# Calamares (installer)
# --------------------------------------------------
systemctl enable calamares.service || true

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
rm -rf /var/cache/pacman/pkg/*
rm -f /root/.bash_history

echo "==> AKSPAlinux customize_airootfs.sh finished"

