#!/usr/bin/env bash
set -euo pipefail

source /etc/ab-release

MOUNT_POINT="/mnt/ab-partner"
mkdir -p "$MOUNT_POINT"

LOCK_FILE="/var/lib/ab-snapshot/last-run"
mkdir -p /var/lib/ab-snapshot
if [ -f "$LOCK_FILE" ] && [ -n "$(find "$LOCK_FILE" -mmin -60)" ]; then
    exit 0
fi

mount "LABEL=${PARTNER_LABEL}" "$MOUNT_POINT"

rsync -aAX --delete \
    --exclude={"/proc/*","/sys/*","/dev/*","/tmp/*","/run/*","/mnt/*","/home/*","/var/log/*"} \
    / "$MOUNT_POINT"/

cat > "$MOUNT_POINT/etc/ab-release" <<EOF
SLOT=${PARTNER}
PARTNER=${SLOT}
PARTNER_LABEL=root${SLOT}
EOF

umount "$MOUNT_POINT"
touch "$LOCK_FILE"
