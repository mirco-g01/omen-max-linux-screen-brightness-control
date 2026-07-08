# Draft upstream bug report

Subject: HP OMEN Max 16-ah0xxx: Hybrid/Advanced Optimus backlight sysfs updates do not affect physical panel brightness; real EC/PWM byte identified

## Summary

On an HP OMEN Max 16-ah0xxx with Intel Arrow Lake integrated graphics (`8086:7d67`) and NVIDIA RTX 5070 Ti Mobile (`10de:2f58`), physical panel brightness cannot be controlled in Hybrid / Advanced Optimus mode under Linux. Backlight sysfs devices accept writes and desktop brightness OSD changes, but physical brightness remains unchanged.

The internal eDP panel is connected to the Intel GPU in Hybrid mode, but neither `intel_backlight`, `acpi_video0/1`, nor `nvidia_wmi_ec_backlight` changes physical brightness. The issue persists across Fedora 43, Fedora 44, Ubuntu, and kernels in the 6.19/7.0/7.1 range.

Using ACPI table analysis and `/proc/acpi/call`, the firmware path was traced to Intel OpRegion mailbox backlight fields. The firmware updates `BCL1`, but the physical brightness does not change. The real physical brightness control byte was identified as `ECPW` at physical address `0xFD400CF5`; writing a byte there changes the panel brightness immediately.

## Hardware

- Manufacturer: HP
- Product: OMEN MAX Gaming Laptop 16-ah0xxx
- CPU/iGPU: Intel Arrow Lake graphics, PCI ID `8086:7d67`
- dGPU: NVIDIA GB205M / GeForce RTX 5070 Ti Mobile, PCI ID `10de:2f58`
- Firmware mode: Hybrid / Advanced Optimus

## Kernel/device observations

Hybrid mode:

```text
00:02.0 VGA compatible controller: Intel Corporation Arrow Lake-S [Intel Graphics] [8086:7d67]
    Kernel driver in use: i915 or xe
02:00.0 VGA compatible controller: NVIDIA Corporation GB205M [GeForce RTX 5070 Ti Mobile] [10de:2f58]
    Kernel driver in use: nvidia
```

DRM connector status showed:

```text
NVIDIA card eDP: disconnected
Intel card eDP: connected
```

With `xe.force_probe=7d67`, sysfs exposed:

```text
/sys/class/backlight/nvidia_wmi_ec_backlight
```

with:

```text
type = firmware
max_brightness = 100
```

Writes to that device changed the sysfs value but not physical brightness.

With `modprobe.blacklist=nvidia_wmi_ec_backlight acpi_backlight=video`, sysfs exposed:

```text
acpi_video0
acpi_video1
```

The desktop slider/hotkeys changed `acpi_video0`, but physical brightness still did not change.

## ACPI/WMI errors observed

```text
wmi_bus wmi_bus-PNP0C14:00: [Firmware Bug]: WQ00 data block query control method not found
ACPI Error: Aborting method \_SB.WMID.WQBD due to previous error (AE_AML_OPERAND_VALUE)
ACPI Error: Aborting method \_SB.WMID.WQBC due to previous error (AE_AML_OPERAND_VALUE)
ACPI Error: Aborting method \_SB.WMID.WQBE due to previous error (AE_AML_OPERAND_VALUE)
ACPI Error: Aborting method \_SB.WMID.WHCM due to previous error (AE_AML_OPERAND_VALUE)
ACPI Error: Aborting method \_SB.WMID.WMAA due to previous error (AE_AML_OPERAND_VALUE)
```

## ACPI findings

`ssdt12.dsl` contains `_BCM` methods for display devices. `_BCM` calls:

```asl
\_SB.PC00.GFX0.AINT(One, Arg0)
```

`AINT(1, Arg0)` performs:

```asl
BCL1 = ((Arg1 * 0xFF) / 0x64)
BCL1 |= 0x80000000
```

The Intel OpRegion at `/sys/kernel/debug/dri/0000:00:02.0/i915_opregion` changes after calling:

```bash
echo '\_SB.PC00.GFX0.AINT 1 20' | sudo tee /proc/acpi/call
```

Observed result:

```text
BCL1 at OpRegion offset 0x200 = 0x80000033
```

For 100%:

```text
BCL1 at OpRegion offset 0x200 = 0x800000ff
```

However, physical brightness does not change.

Another firmware path references `ECPW`:

```asl
OperationRegion (EWRM, SystemMemory, 0xFD400C00, 0x0100)
Field (EWRM, AnyAcc, NoLock, Preserve)
{
    ...
    Offset (0xF5),
    ECPW, 8,
    ...
}
```

Therefore:

```text
ECPW = physical address 0xFD400CF5
```

The WMI-related method path reads `CBL1` and writes `ECPW`, but the Linux `_BCM/AINT` path updates `BCL1`, while `CBL1` remains at 100%.

## Experimental proof

Directly writing the discovered byte changes physical brightness:

```bash
sudo busybox devmem 0xFD400CF5 8 0x28   # panel dims
sudo busybox devmem 0xFD400CF5 8 0x64   # panel returns to high brightness
```

A userspace daemon that monitors `/sys/class/backlight/acpi_video0/brightness` and mirrors the percentage to `0xFD400CF5` makes KDE/GNOME brightness sliders and hotkeys work.

## Hypothesis

The firmware/driver path in Hybrid mode updates Intel OpRegion `BCL1` but does not propagate the requested brightness to the actual EC/PWM byte (`ECPW`). Either:

1. the Intel OpRegion mailbox backlight request is not consumed/applied by `i915`/`xe` on this platform; or
2. HP firmware expects an OEM WMI/EC path to synchronize `CBL1`/`ECPW`, which Linux does not currently implement; or
3. `nvidia_wmi_ec_backlight` is selected as a firmware backlight backend but does not use the correct HP OMEN Max method/register.

## Request

Please advise whether the correct upstream fix should live in:

- `drivers/gpu/drm/i915/display/intel_opregion.c` / `xe` OpRegion handling;
- `drivers/platform/x86/nvidia-wmi-ec-backlight.c`;
- an HP-specific platform driver quirk, likely DMI-matched for HP OMEN Max 16-ah0xxx.

I can test experimental patches on the affected hardware.
