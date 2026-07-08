# Release v0.2.0

## Focus

Safety and install reliability improvements.

## Changes

- Added a dedicated fixed-purpose C helper (`omen-ec-write`) as a safer alternative to calling `busybox devmem` directly.
- Kept `busybox devmem` fallback when `gcc` is unavailable.
- Added stronger installer checks for HP/OMEN DMI data.
- Added `--dry-run` and `--force` installer options.
- Centralized configuration in `/etc/omen-backlight/env`.
- Improved systemd service configuration.
- Improved uninstall process.
- Added troubleshooting and hardware compatibility documentation.

## Tested hardware

- HP OMEN Max 16-ah0xxx
- Intel Arrow Lake graphics
- NVIDIA RTX 5070 Ti Mobile
- Fedora 44
- Linux 7.1.x

## Warning

This is still a userspace workaround. It writes a hardware register discovered through ACPI reverse engineering. Do not use on unsupported hardware unless you have independently verified the register.
