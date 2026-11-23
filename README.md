# Debian USB Install

Deploy Debian 13.8.0 across three servers, then upgrade to sid/forky.

## ISO

Pre-downloaded: `debian-13.8.0-amd64-netinst.iso` (758MB)

## Create USB

```bash
./scripts/create-usb.sh /dev/sdX
```

Creates two 4GB partitions on USB:
- **Partition 1**: Debian installer (bootable)
- **Partition 2**: Post-install scripts (FAT32)

## Workflow

### 1. Create USB stick
```bash
./scripts/create-usb.sh /dev/sdb
```

### 2. Boot server from USB
- Insert USB and boot
- Follow Debian installer prompts
- Use same settings on all three servers
- Reboot after installation

### 3. Run post-install script
```bash
sudo mount /dev/sdX2 /mnt
sudo bash /mnt/post-install.sh
```

Sets hostname, installs basics, enables SSH.

### 4. Optional: Upgrade to sid
```bash
sudo bash /mnt/upgrade-to-sid.sh
```

Changes to Debian unstable (sid/forky) and upgrades.

### 5. Repeat for other servers
Repeat steps 2-4 for second and third server.

## Scripts

- `create-usb.sh` - Create USB with 4GB installer + 4GB scripts partitions
- `post-install.sh` - Configure hostname, install packages, enable SSH
- `upgrade-to-sid.sh` - Switch to sid and upgrade packages
