# Custom Arch Gaming Distro — Build Kit

A real, from-package-list custom Linux distro: Arch base + KDE Plasma +
full gaming stack, built with **archiso** — the same tool EndeavourOS,
CachyOS, and Garuda are built with. You're not compiling from source, but
you control exactly what's in it.

**This must be built on an actual Arch (or Arch-based) machine — not inside
this chat.** archiso only runs on Arch. If you're currently on Nobara, you'll
need a spare machine, VM, or a temporary Arch live USB to do the build itself
(the *result* — your custom ISO — is what you'll actually install and use
day to day).

## What's in this kit
- `packages.x86_64` — the full package list (KDE, Steam, Lutris, Wine,
  GameMode, MangoHud, drivers, codecs, etc.) — **edit this file first**,
  it's your actual package selection.
- `airootfs/` — files overlaid into the live system: autologin, enabled
  services (NetworkManager, sddm, irqbalance), zram config.
- `profiledef.sh.patch-reference` — ISO naming/metadata, merged in automatically.
- `build.sh` — does everything: pulls Arch's official releng template,
  overlays your customizations, runs `mkarchiso`.

## Step 1 — Get an Arch environment to build on
Options, pick one:
- A spare PC/VM with Arch Linux already installed, or
- Boot the **official Arch ISO** (archiso itself, from https://archlinux.org/download/)
  live, connect to wifi/ethernet, and build right there in the live session.

## Step 2 — Get the files onto that machine
Copy `packages.x86_64`, `airootfs/`, `profiledef.sh.patch-reference`, and
`build.sh` into one folder, e.g.:
```bash
mkdir ~/custom-arch-iso && cd ~/custom-arch-iso
# copy/download the files here, preserving the airootfs/ folder structure
```

## Step 3 — Edit your package list
```bash
nano packages.x86_64
```
Add or remove anything. This is the actual definition of your distro —
everything in this file gets installed onto the ISO (and later, onto your
disk, since archiso installs exactly what's on the ISO).

## Step 4 — Build it
```bash
chmod +x build.sh
sudo ./build.sh
```
This will:
1. Install `archiso` + `git`
2. Copy Arch's official `releng` profile as your starting point
3. Drop in your package list, enable multilib (needed for 32-bit gaming libs),
   apply your ISO name/label, and overlay the autologin/services/zram configs
4. Run `mkarchiso` to actually build the `.iso`

Expect **30–90 minutes** depending on your connection — it downloads every
package fresh.

## Step 5 — Find your ISO
```bash
ls out/
```
You'll see something like `customarch-gaming-2026.08.03-x86_64.iso`.

## Step 6 — Make a bootable USB
```bash
sudo dd if=out/customarch-gaming-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```
Replace `/dev/sdX` with your actual USB device (check with `lsblk` first —
picking the wrong device will destroy data on it). Or use **Ventoy**: install
it to the USB once, then just drag the `.iso` file onto it.

## Step 7 — Boot it and install
The ISO boots to a live KDE Plasma desktop with everything from your package
list already present — you can use it live, or install to disk:
```bash
archinstall
```
This is Arch's official guided installer (already included in your package
list). Follow the prompts for disk partitioning, bootloader, hostname, user
account. It'll install using the same package selection already cached on
the ISO, so it's fast.

## After install — NVIDIA users
The package list includes `nvidia-dkms` alongside the open-source drivers
for AMD/Intel so the ISO works on any GPU. Once installed on your actual
hardware, remove whichever driver set you *don't* need to keep the system
clean:
```bash
# if you have AMD/Intel, not NVIDIA:
sudo pacman -Rns nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
```

## Rebuilding after changes
Every time you edit `packages.x86_64` or anything in `airootfs/`, just rerun:
```bash
sudo rm -rf work profile out
sudo ./build.sh
```

## Alternative: build it on GitHub instead of locally

If wrestling with live-USB storage/RAM limits isn't worth it, you can build
in the cloud instead — GitHub Actions can run a privileged Arch container
and hand you back a downloadable ISO. Included: `.github/workflows/build-iso.yml`.

1. Create a **public** GitHub repo (public matters — GitHub's free artifact
   storage is generous for public repos, but capped at 500MB for private
   ones, and your ISO will likely be 2–4GB).
2. Push this whole folder into it, including the `.github/workflows/` folder:
   ```bash
   git init
   git add .
   git commit -m "custom arch gaming iso build"
   git branch -M main
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
3. Go to the repo's **Actions** tab on GitHub → you should see "Build Custom
   Arch Gaming ISO" → click **Run workflow**.
4. Wait for it to finish (roughly the same 30–90 min as building locally,
   sometimes faster on GitHub's hardware).
5. Open the completed run → scroll to **Artifacts** → download
   `custom-arch-gaming-iso` (a zip containing your `.iso`).

This runs `build.sh` exactly as-is inside an official `archlinux` Docker
container with `--privileged` (needed for the loop-device/squashfs work
`mkarchiso` does), so any edits you make to `packages.x86_64` or `airootfs/`
apply the same way as a local build — just commit and push, then re-run
the workflow.

Other cloud options if you'd rather not use GitHub: any VPS/cloud VM running
Arch (e.g. a cheap hourly instance from Hetzner/DigitalOcean/Vultr, or a free
tier if your provider offers one) works the same as a local Arch machine —
SCP the folder over, run `build.sh`, `scp` the resulting `.iso` back down.


- Want a graphical installer instead of `archinstall`'s TUI? Add `calamares`
  and its Arch config to the package list/profile — more setup, ask me if
  you want that wired in.
- Want your own custom Plasma theme/wallpaper/panel layout baked in by
  default? Drop the config files into `airootfs/etc/skel/.config/` — anything
  there gets copied to every new user's home directory, including the one
  `archinstall` creates.
- Want this rebuildable as new package versions come out (a "rolling"
  personal distro)? Just keep this folder around and rerun `build.sh`
  whenever you want a fresh ISO.

---
**Files in this kit:** `packages.x86_64`, `build.sh`, `profiledef.sh.patch-reference`, `airootfs/`, `.github/workflows/build-iso.yml`
