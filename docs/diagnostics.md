# Diagnostics

Starting from v0.3.0-dev, the project includes a diagnostic helper:

```bash
sudo omen-backlight-diagnose
```

The command prints the hardware model, BIOS version, kernel version, GPU devices,
backlight devices, installed configuration, service status and recent logs.

Use this output when opening a hardware compatibility report.

## Why this matters

The current workaround is validated on one HP OMEN Max 16-ah0xxx system using the
EC/PWM register `0xFD400CF5`. Other HP OMEN Max models may use the same register,
but that should not be assumed without diagnostic data.
