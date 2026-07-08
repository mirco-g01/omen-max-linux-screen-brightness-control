# Changelog

## v0.2.1 - Hotfix

- Fixed installer configuration for the systemd sync service.
- Automatically writes `OMEN_ALLOW_CUSTOM_REG=1` for the validated HP OMEN Max register path.
- Fixes a regression where manual `omen-brightness` worked but slider/key synchronization failed with `Custom register refused`.

## v0.2.0

- Add dedicated C helper for the EC/PWM brightness register.
- Add safer installer checks and dry-run mode.
- Add uninstall script improvements.
- Add centralized configuration file.
- Add troubleshooting and hardware compatibility documentation.

## v0.1.0

- Initial public release.
- Add userspace backlight sync service.
- Add scripts to mirror OS slider brightness to the real HP OMEN Max backlight register.
- Add ACPI reverse engineering notes.
