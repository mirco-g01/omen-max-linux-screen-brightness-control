# Upstream Linux kernel fix plan

## Current status

This project currently provides a working userspace workaround for a Linux brightness control issue affecting the tested HP OMEN Max laptop.

The current recommended stable release is:

```text
v0.2.1
```

The workaround has been validated on:

- HP OMEN MAX Gaming Laptop 16-ah0xxx
- BIOS F.22
- Intel Arrow Lake graphics `[8086:7d67]`
- NVIDIA RTX 5070 Ti Mobile `[10de:2f58]`
- Fedora 44
- Linux 7.1.x
- Hybrid / Optimus mode
- Intel `xe` graphics driver
- Linux backlight source: `acpi_video0`
- Validated EC/PWM register: `0xFD400CF5`

## Problem summary

On the tested laptop, Linux exposes backlight devices under:

```text
/sys/class/backlight/
```

The brightness value changes when using the desktop brightness slider or Fn brightness keys.

However, the real internal panel brightness does not change correctly through the standard Linux backlight interface.

Observed behavior:

- `acpi_video0` brightness changes
- `acpi_video1` is also present
- `nvidia_wmi_ec_backlight` can appear depending on kernel parameters
- writing to the exposed Linux backlight devices does not reliably change the real panel brightness
- direct writes to the validated EC/PWM register `0xFD400CF5` do change the real panel brightness

## Userspace workaround

The current workaround synchronizes the Linux-visible brightness value with the real panel brightness by writing to the validated EC/PWM register.

The workaround includes:

- `omen-brightness`
- `omen-brightness-step`
- `omen-backlight-sync`
- a systemd service
- a dedicated helper for writing the validated brightness value

This is useful for affected users, but it is not a proper upstream Linux kernel fix.

## Why this is not yet an upstream fix

The current solution is intentionally implemented as a userspace workaround.

It should not be submitted upstream in its current form because:

- it writes to a hardware-specific register from userspace
- the register is currently validated only on one tested machine
- firmware or BIOS updates may change behavior
- other OMEN Max models may use different firmware paths
- a kernel-side fix needs to integrate with the Linux backlight subsystem properly

## Goal

The long-term goal is to identify the correct kernel-side fix.

Possible upstream directions include:

- a model-specific quirk
- an ACPI/backlight handling fix
- a platform/x86 or HP WMI related fix
- a corrected backlight backend selection for this hardware
- a dedicated platform-specific backlight implementation if appropriate

The final solution should make the standard Linux brightness interface update the real panel brightness without requiring a userspace polling service.

## Information needed before upstream submission

Before contacting Linux kernel maintainers or submitting a patch, more data should be collected.

For each tested system, collect:

- exact laptop model
- product name from DMI
- product version from DMI
- BIOS version
- BIOS date
- Linux distribution
- kernel version
- kernel command line
- GPU mode: Hybrid / Optimus / Discrete
- Intel GPU PCI ID
- NVIDIA GPU PCI ID
- active Intel driver: `i915` or `xe`
- available `/sys/class/backlight` devices
- whether manual backlight writes change the real panel brightness
- whether Fn keys and desktop slider work
- whether the workaround works
- service logs if the workaround is installed

## Minimum upstream report contents

A first upstream report should include:

```text
Subject:
HP OMEN Max 16-ah0xxx: backlight sysfs changes but real panel brightness does not change

Hardware:
- HP OMEN MAX Gaming Laptop 16-ah0xxx
- BIOS F.22
- Intel Arrow Lake graphics [8086:7d67]
- NVIDIA RTX 5070 Ti Mobile [10de:2f58]
- Hybrid / Optimus mode

Kernel:
- Linux 7.1.x
- Intel xe driver
- NVIDIA proprietary driver present
- acpi_backlight=video
- nvidia_wmi_ec_backlight blacklisted

Problem:
- /sys/class/backlight/acpi_video0 brightness changes
- real panel brightness does not change through the normal Linux backlight interface
- nvidia_wmi_ec_backlight is also ineffective on this system
- ACPI methods exist but do not appear to update the real panel brightness path

Workaround discovered:
- EC/PWM register 0xFD400CF5 controls real panel brightness on the tested machine
- writing values from 5 to 100 changes the real panel brightness
- userspace workaround confirms the hardware path

Expected behavior:
- desktop slider and Fn brightness keys should update the real internal panel brightness through the standard Linux backlight interface

Goal:
- identify the correct kernel-side fix or model-specific quirk
```

## Upstream process

The preferred process is:

1. keep the userspace workaround clearly documented as a workaround
2. collect compatibility reports from affected users
3. identify whether the issue is model-specific or affects a wider OMEN Max family
4. prepare a detailed upstream bug report
5. identify the correct Linux subsystem and maintainers
6. discuss the issue with maintainers before proposing invasive changes
7. only then prepare a kernel patch if the correct fix is understood

## Possible kernel areas

Likely areas to investigate:

- ACPI video backlight handling
- Linux backlight subsystem
- HP WMI / platform-x86 drivers
- Intel graphics backlight interaction
- firmware-specific DMI quirks

The exact maintainers should be identified from the Linux kernel source tree using:

```bash
scripts/get_maintainer.pl
```

against the relevant files or patch.

## Communication strategy

When posting publicly, describe the project carefully.

Good wording:

```text
This is a working userspace workaround for an HP OMEN Max Linux brightness issue.
I am collecting compatibility data to investigate a proper upstream Linux kernel fix.
```

Avoid claiming:

```text
This is the official fix.
```

or:

```text
This is ready for upstream.
```

## Current recommendation

For affected users, the current recommended release is:

```text
v0.2.1
```

Development work toward upstreaming should happen only in separate branches.

The `main` branch should remain aligned with the last validated stable release until a safer and well-tested version is ready.
