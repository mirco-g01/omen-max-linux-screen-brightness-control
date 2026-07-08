# Local install guide

```bash
sudo dnf install busybox
sudo install -m 0755 scripts/omen-brightness /usr/local/bin/omen-brightness
sudo install -m 0755 scripts/omen-brightness-step /usr/local/bin/omen-brightness-step
sudo install -m 0755 scripts/omen-backlight-sync /usr/local/bin/omen-backlight-sync
sudo install -m 0644 systemd/omen-backlight-sync.service /etc/systemd/system/omen-backlight-sync.service
sudo systemctl daemon-reload
sudo systemctl enable --now omen-backlight-sync.service
```

The sync daemon currently assumes the OS slider source is:

```text
/sys/class/backlight/acpi_video0
```

This matched the tested Fedora/KDE system after booting with:

```text
i915.force_probe=!7d67 xe.force_probe=7d67 acpi_backlight=video modprobe.blacklist=nvidia_wmi_ec_backlight
```

If a different sysfs backlight source changes on another system, edit `BACKLIGHT=` in `scripts/omen-backlight-sync`.
