# Hardware compatibility

## Confirmed working

| Vendor | Model | CPU/GPU platform | Distro | Kernel | Notes |
|---|---|---|---|---|---|
| HP | OMEN Max 16-ah0xxx | Intel Arrow Lake + NVIDIA RTX 5070 Ti Mobile | Fedora 44 | 7.1.x | Hybrid/Optimus mode |

## Unknown / untested

Other HP OMEN Max variants may use a different EC/PWM register. Do not assume the register is identical without ACPI validation.

## Required symptom pattern

This workaround is intended for systems where:

- The OS brightness slider or keys move normally.
- `/sys/class/backlight/.../brightness` changes.
- The real panel brightness does not change.
- Direct write to the validated EC/PWM register changes brightness.

## Safety note

The default register used by this project is:

```text
0xFD400CF5
```

This was validated on one HP OMEN Max 16-ah0xxx unit. It should not be treated as universal for all HP laptops.
