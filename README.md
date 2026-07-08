# HP OMEN Max Linux Backlight Workaround and Reverse Engineering Notes

> **v0.2.1 hotfix:** fixes the v0.2.0 service configuration regression where manual brightness commands worked but slider/key synchronization failed with `Custom register refused`.


This repository documents and works around a Linux backlight control problem observed on an HP OMEN Max 16-ah0xxx laptop with Intel Arrow Lake graphics and an NVIDIA RTX 5070 Ti Mobile GPU in Hybrid / Advanced Optimus mode.

## Current status

A userspace workaround is functional: the OS-visible ACPI backlight slider changes `/sys/class/backlight/acpi_video0/brightness`; a small daemon mirrors that percentage to the real EC/PWM byte at physical address `0xFD400CF5`. This makes KDE/GNOME brightness sliders and hotkey OSD changes affect the actual panel brightness.

This is not intended as the final upstream solution. It is a proof-of-cause and practical workaround while a kernel-side fix is developed.

## Affected hardware tested

- Vendor: HP
- Product family: OMEN MAX Gaming Laptop 16-ah0xxx
- CPU/platform: Intel Core Ultra 7 255HX / Arrow Lake graphics `8086:7d67`
- dGPU: NVIDIA RTX 5070 Ti Mobile / GB205M `10de:2f58`
- Firmware mode: Hybrid / Advanced Optimus
- Distros tested: Fedora 43, Fedora 44, Ubuntu with newer kernel
- Kernel tested by reporter: 6.19.x, 7.0.x, 7.1.x

## Symptoms

- In Discrete Only mode, physical brightness works.
- In Hybrid / Advanced Optimus mode, the internal eDP panel is connected on Intel graphics.
- Linux exposes backlight devices such as `intel_backlight`, `acpi_video0`, `acpi_video1`, or `nvidia_wmi_ec_backlight`, depending on kernel parameters and Intel driver (`i915` vs `xe`).
- Writing those backlight devices updates sysfs values and the desktop OSD, but the physical panel brightness does not change.
- With `xe`, `nvidia_wmi_ec_backlight` may appear with `type=firmware`, but writes still do not affect physical brightness.

## Key discovery

The real physical brightness register was experimentally identified as:

```text
0xFD400CF5
```

Writing one byte there changes the physical panel brightness immediately:

```bash
sudo busybox devmem 0xFD400CF5 8 0x28
sudo busybox devmem 0xFD400CF5 8 0x64
```


## One-command local install from repository checkout

Recommended install with the dedicated helper:

```bash
sudo dnf install gcc
sudo ./install.sh
```

Fallback install using `busybox devmem` if `gcc` is unavailable:

```bash
sudo dnf install busybox
sudo ./install.sh
```

Uninstall:

```bash
sudo ./uninstall.sh
```

The installer performs basic DMI safety checks and refuses automatic installation on non-HP/non-OMEN systems unless `OMEN_FORCE_INSTALL=1` is explicitly set.

## Manual workaround installation

The automatic installer is recommended. Manual installation is primarily useful for development.

Install dependencies:

```bash
sudo dnf install gcc
```

Install scripts:

```bash
sudo install -m 0755 scripts/omen-brightness /usr/local/bin/omen-brightness
sudo install -m 0755 scripts/omen-brightness-step /usr/local/bin/omen-brightness-step
sudo install -m 0755 scripts/omen-backlight-sync /usr/local/bin/omen-backlight-sync
```

Install the systemd service:

```bash
sudo install -m 0644 systemd/omen-backlight-sync.service /etc/systemd/system/omen-backlight-sync.service
sudo systemctl daemon-reload
sudo systemctl enable --now omen-backlight-sync.service
```

Check status:

```bash
systemctl status omen-backlight-sync.service
```

Manual test:

```bash
sudo omen-brightness 30
sudo omen-brightness 80
```

## Important safety note

This workaround writes a model-specific physical address. Since v0.2.1 the installer prefers a fixed-purpose C helper and uses `busybox devmem` only as a fallback. It was validated on the tested HP OMEN Max 16-ah0xxx unit, but should not be assumed safe on other machines without ACPI confirmation. The proper final solution should be a kernel driver quirk or firmware-method implementation, not permanent arbitrary userspace physical memory access.

## Reverse engineering summary

The ACPI tables show standard backlight methods in `ssdt12.dsl`:

```text
_BCM(Arg0) -> \_SB.PC00.GFX0.AINT(One, Arg0)
```

`AINT(1, value)` updates Intel OpRegion mailbox backlight state:

```text
BCL1 = ((value * 0xFF) / 0x64) | 0x80000000
```

This was verified with `/proc/acpi/call` and by comparing `/sys/kernel/debug/dri/0000:00:02.0/i915_opregion` before/after:

```text
AINT 1 20 -> OpRegion offset 0x200 becomes 0x80000033
AINT 1 100 -> OpRegion offset 0x200 becomes 0x800000ff
```

However, physical brightness does not change when only BCL1 changes.

Another firmware path reads `CBL1` and writes `ECPW`:

```text
WMAA MODF=1 -> Local1 = CBL1; Local3 = Local1 * 2; ECPW = Local3
```

`ECPW` is an ACPI Field mapped to physical memory:

```text
OperationRegion EWRM, SystemMemory, 0xFD400C00, 0x0100
Offset 0xF5 -> ECPW, 8
```

Therefore:

```text
ECPW physical address = 0xFD400C00 + 0xF5 = 0xFD400CF5
```

The observed bug is that the firmware/driver path updates `BCL1` but does not propagate the requested brightness to `CBL1`/`ECPW` in Hybrid mode.

## Candidate upstream direction

The final fix should avoid `devmem`. Possible approaches:

1. Add an HP OMEN Max DMI quirk in a platform driver that exposes a proper backlight device and writes the mapped EC/PWM byte through a safe kernel mapping.
2. Fix Intel OpRegion/ASLE mailbox handling if the expected behavior is that the graphics driver consumes `BCL1` and applies the panel brightness itself.
3. Identify the Windows/HP WMI method that correctly updates `ECPW`, and implement that path in Linux instead of writing the memory-mapped byte directly.

See `docs/upstream-report.md` for a draft bug report.


## v0.2.1 safety improvements

- Dedicated fixed-purpose C helper for the validated EC/PWM register.
- `busybox devmem` retained only as a fallback.
- Installer `--dry-run` mode.
- Installer `--force` mode for manually validated hardware only.
- Centralized configuration in `/etc/omen-backlight/env`.
- Improved troubleshooting documentation.

```bash
sudo ./install.sh --dry-run
sudo ./install.sh
```

See also:

- `docs/troubleshooting.md`
- `docs/hardware-compatibility.md`
- `CHANGELOG.md`
