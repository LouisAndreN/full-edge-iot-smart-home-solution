EMERGENCY RECOVERY PARTITION
============================

This partition contains:
- LUKS header backup (backup/luks-header-backup.img)
- LUKS keyfile backup (backup/luks-keyfile)
- Recovery scripts (scripts/)
- Emergency tools

LUKS CONFIGURATION:
- If using rescue USB: ensure kernel 5.9+ or decrypt will FAIL
- Ubuntu 22.04+ live USB recommended (kernel 6.2+)

DISASTER RECOVERY STEPS:
1. Boot from USB/SD card with kernel 5.9+ (check: uname -r)
2. Mount this partition: mount /dev/nvme0n1p4 /mnt
3. Run: bash /mnt/scripts/unlock-luks.sh
4. Mount filesystems as needed

LUKS HEADER RESTORE:
cryptsetup luksHeaderRestore /dev/nvme0n1p5 --header-backup-file /mnt/backup/luks-header-backup.img

LUKS DIAGNOSTICS:
# Show LUKS header info and key slots
cryptsetup luksDump /dev/nvme0n1p5

# Check sector size (should show 4096)
cryptsetup luksDump /dev/nvme0n1p5 | grep "sector size"
# Output: Payload sector size:     4096

# Check which key slots are active
# Slot 0: Original passphrase
# Slot 1: Keyfile (/boot/luks-keyfile)

PASSPHRASE RECOVERY:
If passphrase forgotten but keyfile available:
1. Boot with keyfile (automatic)
2. Add new passphrase:
   cryptsetup luksAddKey /dev/nvme0n1p5 --key-file /boot/luks-keyfile
3. Remove old passphrase (if known slot):
   cryptsetup luksKillSlot /dev/nvme0n1p5 0

COMPLETE FAILURE (both passphrase + keyfile lost):
Data is UNRECOVERABLE (encryption working as designed)
This is why backups exist (/mnt/data/backups)

System: Raspberry Pi 5 + NVMe 1TB
