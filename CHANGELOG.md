# Changelog

## v0.3.0

- **Fix EC register scale bug**: the real HP OMEN Max panel register is 0-200,
  not 0-100. `omen-ec-write` silently clamped every write to 100 regardless
  of `OMEN_BACKLIGHT_MAX`, so `omen-brightness 100` only ever reached ~50% of
  true panel brightness. The helper now allows up to 200, and `omen-brightness`
  converts the user-facing 0-100 percent to/from the register's native 0-200
  scale transparently.
- **Prefer `intel_backlight` as the sync source**: on Advanced Optimus HP
  OMEN Max hardware, the WMI-based `nvidia_wmi_ec_backlight` device is known
  to accept writes that never reach the panel (the firmware's brightness AML
  method recomputes the EC register from an Intel graphics OpRegion field —
  `CBL1`, mailbox 2 — that the graphics driver never writes, so it always
  resets to a fixed value). `intel_backlight` (native i915/eDP PWM) is a
  purely software-visible value with no physical effect on its own, but it's
  what the desktop's brightness slider/Fn keys actually update — mirroring
  *that* to the real EC register via the fixed helper above is what makes
  slider/hotkey control work end-to-end. Autodetect priority updated
  accordingly in both the installer and `omen-backlight-sync`.
- **`--fix-bootloader` installer flag**: `intel_backlight` only exists when
  the kernel boots with `acpi_backlight=native`. The installer now detects
  when it's missing and, with `--fix-bootloader`, can patch a systemd-boot
  entry automatically (with backup) — also removing `i915.enable_dpcd_backlight=1`
  if present, since it's redundant/can interfere once native mode works.
  Manual instructions are printed for GRUB/other bootloaders.
- Default `OMEN_BACKLIGHT_MIN` lowered from 5 to 0 — the register's true
  floor turns the backlight fully off, which is valid and expected.
- Installer no longer hardcodes a single default slider source (previously
  always `acpi_video0`, which silently doesn't exist on newer kernels/`xe`);
  it now probes the same priority list as the sync daemon at install time.

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
