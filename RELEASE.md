# HP OMEN Max Linux Brightness Fix v0.2.1

Hotfix release for v0.2.0.

## Fixed

- The installer now writes `OMEN_ALLOW_CUSTOM_REG=1` to `/etc/omen-backlight/env`.
- This fixes the systemd sync service refusing to apply brightness changes with:

```text
Custom register refused. Set OMEN_ALLOW_CUSTOM_REG=1 only after validating your ACPI tables.
```

## Notes

If v0.2.0 is already installed and manual brightness commands work but the KDE/GNOME slider does not, either install v0.2.1 or add this line manually to `/etc/omen-backlight/env`:

```bash
OMEN_ALLOW_CUSTOM_REG=1
```

Then restart the service:

```bash
sudo systemctl restart omen-backlight-sync.service
```
