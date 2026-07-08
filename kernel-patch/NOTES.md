# Kernel patch notes

This directory is intentionally a design note, not a tested kernel patch yet.

The working userspace proof writes one byte to physical address `0xFD400CF5`, derived from ACPI:

```text
OperationRegion (EWRM, SystemMemory, 0xFD400C00, 0x0100)
Offset (0xF5), ECPW, 8
```

A real kernel patch should not hard-code arbitrary physical memory access without a DMI quirk and a safe mapping strategy.

Possible implementation directions:

1. Platform driver quirk:
   - DMI match HP OMEN Max 16-ah0xxx / board `103c:8d41`.
   - Register a backlight device.
   - Map the ACPI EWRM region safely.
   - On brightness update, write validated 5-100 value to ECPW.

2. Intel OpRegion/ASLE handling:
   - Investigate whether mailbox #2 backlight fields BCL1/CBL1 should be consumed by i915/xe.
   - If the graphics driver is responsible, translate BCL1 requests to the actual panel backlight operation.

3. HP/NVIDIA WMI path:
   - Investigate whether a WMI method exists under Windows that synchronizes CBL1/ECPW.
   - If so, implement that method instead of direct EC/PWM memory writes.
