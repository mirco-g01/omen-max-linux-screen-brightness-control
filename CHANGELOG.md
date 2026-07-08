# Changelog

## v0.3.0-dev

Development snapshot focused on diagnostics and compatibility reporting.

### Added

- Added `omen-backlight-diagnose` diagnostic script.
- Added GitHub hardware compatibility issue template.
- Added diagnostics documentation.
- Installer now installs the diagnostic script.
- Uninstaller now removes the diagnostic script.

### Unchanged

- The working v0.2.1 brightness logic is unchanged.
- The validated register remains `0xFD400CF5`.
- The default backlight source remains `/sys/class/backlight/acpi_video0`.

## v0.2.1

Hotfix for v0.2.0.

- Fixed installer service configuration.
- Automatically writes `OMEN_ALLOW_CUSTOM_REG=1` for the validated custom register.

## v0.2.0

- Added dedicated `omen-ec-write` helper.
- Added safer installer checks.
- Added centralized configuration.

## v0.1.0

- Initial public release.
