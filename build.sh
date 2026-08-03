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

# Merge our profiledef.sh overrides into the copied one (pure bash/sed —
# no python needed, since minimal build containers don't include it)
while IFS= read -r line; do
  # skip blank lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue
  key="${line%%=*}"
  case "$key" in
    buildmodes|bootmodes|file_permissions) continue ;;  # leave releng array defaults alone
  esac
  if grep -q "^${key}=" "$PROFILE_DIR/profiledef.sh"; then
    esc_line=$(printf '%s' "$line" | sed -e 's/[&\\]/\\&/g' -e 's/|/\\|/g')
    sed -i "s|^${key}=.*|${esc_line}|" "$PROFILE_DIR/profiledef.sh"
  fi
done < "$WORKDIR/profiledef.sh.patch-reference"
echo "profiledef.sh updated (iso_name, iso_label, install_dir, etc.)"

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
