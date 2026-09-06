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

The sync daemon auto-detects the OS-visible slider source, preferring (in order)
`intel_backlight`, `nvidia_wmi_ec_backlight`, `acpi_video0`, `acpi_video1`.
`intel_backlight` only exists when the kernel boots with:

```text
acpi_backlight=native
```

See `install.sh --fix-bootloader` to apply that automatically, or the main
README's Installation section for manual bootloader instructions.

If a different sysfs backlight source changes on your system, edit
`OMEN_BACKLIGHT_SOURCE` in `/etc/omen-backlight/env`, or the priority list in
`scripts/omen-backlight-sync` directly.
