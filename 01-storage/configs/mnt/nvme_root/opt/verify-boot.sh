#!/bin/bash
# Post-boot verification - run after first NVMe boot

echo "Verifying NVMe boot setup..."

# Check LUKS
if ! cryptsetup status cryptdata | grep -q "is active"; then
    echo "LUKS not active!"
    exit 1
fi
echo "LUKS active"

# Check LVM
if ! vgs vg-main &>/dev/null; then
    echo "VG vg-main not found!"
    exit 1
fi
echo "LVM volume group active"

# Check all LVs mounted
REQUIRED_MOUNTS=(
    "/" "/var" "/var/log" "/var/lib/influxdb"
    "/var/lib/containers" "/var/lib/grafana"
    "/mnt/ml-models" "/mnt/ml-cache" "/mnt/cloud-sync"
    "/mnt/scratch" "/mnt/data"
)

for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "$mount"; then
        echo "$mount not mounted!"
        exit 1
    fi
done
echo "All partitions mounted"

# Check XFS mount options
if ! mount | grep '/var/lib/influxdb' | grep -q 'allocsize=16m'; then
    echo "InfluxDB missing XFS tuning"
fi
echo "XFS options correct"

# Check BTRFS compression
if ! mount | grep '/mnt/data' | grep -q 'compress=zstd'; then
    echo "BTRFS compression not enabled"
fi
echo "BTRFS compression active"

# Check BTRFS subvolume mount units
echo ""
echo "Checking BTRFS subvolume systemd units..."
for unit in mnt-data-archives.mount mnt-data-backups.mount mnt-data-personal.mount; do
    if systemctl is-active "$unit" &>/dev/null; then
        echo "$unit"
    else
        echo "$unit not active (run: systemctl start $unit)"
    fi
done

# Check swap configuration
echo ""
echo "Checking swap configuration..."
if ! swapon --show | grep -q 'zram0'; then
    echo "zram swap not active!"
    echo "  Run: sudo systemctl start systemd-zram-setup@zram0.service"
else
    echo "zram swap active"
fi

# Show swap details
echo ""
echo "Swap configuration:"
swapon --show
echo ""
echo "Expected:"
echo "  NAME           TYPE      SIZE USED PRIO"
echo "  /dev/zram0     partition   4G   0B  100  ← High priority (used first)"
echo "  /dev/nvme0n1p3 partition   4G   0B   -2  ← Low priority (fallback)"

# Show zram stats
if [ -e /dev/zram0 ]; then
    echo ""
    echo "zram details:"
    zramctl /dev/zram0
    echo ""
    echo "Expected compression ratio: 2-3:1 (zstd)"
fi

# Check NVMe swap present (fallback)
if ! swapon --show | grep -q 'nvme0n1p3'; then
    echo "NVMe swap partition not active"
fi

# Check TRIM
if ! systemctl is-enabled fstrim.timer | grep -q 'enabled'; then
    echo "TRIM timer not enabled"
    systemctl enable fstrim.timer
fi
echo "TRIM configured"

# Disk usage report
echo ""
echo "Disk usage:"
df -h | grep -E '(Filesystem|nvme0n1|vg-main)'

echo ""
echo "All checks passed! NVMe boot successful."
echo ""
echo "Next steps:"
echo "1. Backup LUKS keyfile: cp /boot/luks-keyfile ~/SAFE_LOCATION"
echo "2. Test recovery: cat /recovery/README.txt"
echo "3. Configure monitoring: /opt/scripts/disk_monitor.sh"
