#!/usr/bin/env bash
# ============================================================
# build.sh — assembles the custom Arch gaming ISO profile and
# builds it with mkarchiso.
#
# MUST be run on an Arch (or Arch-based, e.g. EndeavourOS/Manjaro)
# machine with root. Needs ~15GB+ free disk.
#
# Usage:
#   ./build.sh
# ============================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo ./build.sh"
  exit 1
fi

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$WORKDIR/profile"
OUT_DIR="$WORKDIR/out"

echo "==> [1/5] Installing archiso + build tools"
pacman -Sy --needed --noconfirm archiso git

echo "==> [2/5] Starting from Arch's official releng template"
rm -rf "$PROFILE_DIR"
cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"

echo "==> [3/5] Overlaying custom package list + profile settings"
cp "$WORKDIR/packages.x86_64" "$PROFILE_DIR/packages.x86_64"

# Enable multilib in the profile's pacman.conf (needed for lib32-* gaming pkgs)
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "$PROFILE_DIR/pacman.conf"

# Merge our profiledef.sh overrides into the copied one
python3 - "$PROFILE_DIR/profiledef.sh" "$WORKDIR/profiledef.sh.patch-reference" <<'PYEOF'
import re, sys
target, patch = sys.argv[1], sys.argv[2]
with open(target) as f:
    content = f.read()
with open(patch) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key = line.split('=', 1)[0].strip()
        if key in ('buildmodes', 'bootmodes', 'file_permissions'):
            continue  # leave releng defaults for these, they're arrays
        pattern = re.compile(rf'^{re.escape(key)}=.*$', re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(line, content)
with open(target, 'w') as f:
    f.write(content)
print("profiledef.sh updated (iso_name, iso_label, install_dir, etc.)")
PYEOF

echo "==> [4/5] Overlaying custom airootfs files (autologin, zram) + enabling services"
cp -r "$WORKDIR/airootfs/." "$PROFILE_DIR/airootfs/"

SYSD_DIR="$PROFILE_DIR/airootfs/etc/systemd/system"
mkdir -p "$SYSD_DIR/multi-user.target.wants" "$SYSD_DIR/graphical.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$SYSD_DIR/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/irqbalance.service "$SYSD_DIR/multi-user.target.wants/irqbalance.service"
ln -sf /usr/lib/systemd/system/reflector.service "$SYSD_DIR/multi-user.target.wants/reflector.service"
ln -sf /usr/lib/systemd/system/sddm.service "$SYSD_DIR/graphical.target.wants/sddm.service"
ln -sf /usr/lib/systemd/system/graphical.target "$SYSD_DIR/default.target"

echo "==> [5/5] Building the ISO (this will take a while)"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
mkarchiso -v -w "$WORKDIR/work" -o "$OUT_DIR" "$PROFILE_DIR"

echo ""
echo "============================================================"
echo "Done. Your ISO is in: $OUT_DIR/"
echo "Flash it to a USB with Ventoy, or:"
echo "  sudo dd if=$OUT_DIR/*.iso of=/dev/sdX bs=4M status=progress oflag=sync"
echo "(replace /dev/sdX with your actual USB device — check with lsblk first!)"
echo "============================================================"
