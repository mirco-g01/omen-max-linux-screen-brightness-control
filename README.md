# omen-max-linux-brightness-control

Real panel brightness control for the **HP OMEN Max 16-ah0xxx** under Linux, in
Hybrid / Advanced Optimus mode (Intel iGPU + NVIDIA dGPU). On this hardware the
standard Linux backlight interface moves the desktop slider and the sysfs
value, but the physical panel stays exactly where it was — this project traces
why, and drives the real hardware register instead.

Started as reverse-engineering work by **kcamporacosta**; that repository has
since been taken down from GitHub, so this one continues it under the same
MIT license, with a real fix for a scaling bug in the original workaround and
some further hardening. See [Credits and licence](#credits-and-licence).

## The problem

- The OS brightness slider and Fn keys move normally.
- `/sys/class/backlight/.../brightness` changes.
- The **physical panel brightness does not change**.

This affects HP OMEN Max laptops with Intel Arrow Lake graphics and an NVIDIA
GPU running in Hybrid/Advanced Optimus mode, where the internal eDP panel is
wired to the Intel GPU. Neither `intel_backlight`, `acpi_video0/1`, nor
`nvidia_wmi_ec_backlight` moves the real backlight — see
[Reverse engineering summary](#reverse-engineering-summary) for why.

## What it does

The real physical brightness register was identified experimentally at
physical address `0xFD400CF5`. A small daemon, `omen-backlight-sync`, watches
the OS-visible backlight device and mirrors its percentage to that register,
so the desktop's slider and Fn-key OSD end up actually changing the panel.

The kernel must be booted with `acpi_backlight=native` so it registers a
native `intel_backlight` device for the eDP panel. On this hardware that
device has **no physical effect on its own** — writing to it does nothing —
but it's the thing the desktop's brightness slider and Fn-key OSD actually
update, so it's what gets mirrored to the real register. Without
`acpi_backlight=native`, the kernel instead exposes `nvidia_wmi_ec_backlight`,
which accepts writes that silently never reach the panel; the sync daemon
still runs in that case, but nothing physically happens.

This is not intended as the final upstream solution — it's a proof-of-cause
and a practical workaround while a kernel-side fix is developed. See
[docs/upstream-plan.md](docs/upstream-plan.md).

## Tested on

```
OS:         Arch Linux x86_64
Host:       OMEN MAX Gaming Laptop 16-ah0xxx   (board 8D41, family 103C_5335M7)
Kernel:     Linux 7.1.11-arch1-1
DE:         KDE Plasma 6.7.4 · KWin (Wayland)
CPU:        Intel Core Ultra 7 255HX (8+12)
GPU:        NVIDIA GeForce RTX 5070 Ti Mobile [10de:2f58] · Intel Arrow Lake-S graphics [8086:7d67]
Memory:     16 GB
BIOS:       Insyde F.23
Boot:       systemd-boot, acpi_backlight=native
Backlight:  intel_backlight (native i915/eDP PWM) mirrored to EC register 0xFD400CF5
```

That's the machine this was actually verified on, including the v0.3.0
register-scale fix below. The original project additionally reported (not
independently re-verified here) similar behavior on:

- Fedora 43, Fedora 44, and Ubuntu with a newer kernel
- Kernels in the 6.19.x / 7.0.x / 7.1.x range

Other OMEN Max boards may use a different EC/PWM register — do not assume
`0xFD400CF5` is universal without ACPI validation on your own machine (see
[docs/hardware-compatibility.md](docs/hardware-compatibility.md)). If yours
works, or doesn't, say so in an issue and this table will grow.

## Reverse engineering summary

The ACPI tables show standard backlight methods in `ssdt12.dsl`:

```text
_BCM(Arg0) -> \_SB.PC00.GFX0.AINT(One, Arg0)
```

`AINT(1, value)` updates the Intel OpRegion mailbox backlight state:

```text
BCL1 = ((value * 0xFF) / 0x64) | 0x80000000
```

This was verified with `/proc/acpi/call` and by comparing
`/sys/kernel/debug/dri/0000:00:02.0/i915_opregion` before/after:

```text
AINT 1 20  -> OpRegion offset 0x200 becomes 0x80000033
AINT 1 100 -> OpRegion offset 0x200 becomes 0x800000ff
```

However, physical brightness does not change when only `BCL1` changes.

Another firmware path reads `CBL1` and writes `ECPW`:

```text
WMAA MODF=1 -> Local1 = CBL1; Local3 = Local1 * 2; ECPW = Local3
```

`ECPW` is an ACPI field mapped to physical memory:

```text
OperationRegion (EWRM, SystemMemory, 0xFD400C00, 0x0100)
Offset (0xF5), ECPW, 8
```

So `ECPW`'s physical address is `0xFD400C00 + 0xF5 = 0xFD400CF5`, and its
**native range is 0-200** — the `Local1 * 2` above, where `Local1`/`CBL1` is
itself a 0-100 value. `0xC8` (200) is true 100% brightness, not `0x64` (100).

The bug: the firmware/driver path in Hybrid mode updates `BCL1` but never
propagates the brightness request to `CBL1`/`ECPW`. Raw ACPI snippets backing
this are in [`acpi-snippets/`](acpi-snippets/); the full write-up is in
[docs/upstream-report.md](docs/upstream-report.md).

## Installation

### Prerequisites

- An HP OMEN Max laptop in Hybrid/Advanced Optimus mode matching the symptom
  pattern above (see [docs/hardware-compatibility.md](docs/hardware-compatibility.md)
  before assuming the register is the same on your unit).
- `gcc`, to build the dedicated EC-write helper (recommended), **or**
  `busybox`, as a fallback that uses `devmem` directly.
- `systemd`, for the sync service and for `--fix-bootloader` on systemd-boot.
- Root access to `/dev/mem` (used by the helper to write the validated
  physical address) and, if patching the bootloader automatically, write
  access to `/boot/loader/entries` (systemd-boot) or `/etc/default/grub` plus
  `grub-mkconfig`/`grub2-mkconfig`/`update-grub` (GRUB) — see
  [--fix-bootloader](#--fix-bootloader) below.

### One-command install

```bash
sudo dnf install gcc   # or: sudo pacman -S gcc / sudo apt install gcc
sudo ./install.sh
```

Fallback if `gcc` is unavailable:

```bash
sudo dnf install busybox
sudo ./install.sh
```

The installer refuses to run on non-HP/non-OMEN systems unless
`OMEN_FORCE_INSTALL=1` is explicitly set.

### `--fix-bootloader`

`intel_backlight` only exists once the kernel boots with
`acpi_backlight=native`. If the installer warns that it's missing:

```bash
sudo ./install.sh --fix-bootloader
```

This detects and patches whichever bootloader is present, backing up the
config it touches first:

- **systemd-boot** — adds `acpi_backlight=native` to every entry under
  `/boot/loader/entries/*.conf` (and drops the now-redundant
  `i915.enable_dpcd_backlight=1` if present).
- **GRUB** — adds it to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`,
  then regenerates `grub.cfg` with whichever of `grub2-mkconfig`,
  `grub-mkconfig`, or `update-grub` is available on your distro (Fedora/RHEL/
  openSUSE, Arch, and Debian/Ubuntu respectively).

Reboot afterwards for the kernel parameter to take effect. If your bootloader
is neither of those (e.g. rEFInd), the installer prints the manual GRUB/kernel
command-line steps to do the equivalent.

### Manual install

See [docs/local-install.md](docs/local-install.md).

### Uninstall

```bash
sudo ./uninstall.sh
```

## Usage

```bash
sudo omen-brightness 30     # set 30%
sudo omen-brightness 80     # set 80%
systemctl status omen-backlight-sync.service
journalctl -u omen-backlight-sync.service -f
```

`omen-brightness`/`omen-ec-write` take a 0-100 percent and handle the 0-200
register scaling internally.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) — covers checking
which backlight source is active, service logs, and what to do if the slider
moves but the panel doesn't.

## Safety note

This workaround writes a model-specific physical address from userspace.
It's validated on the machine listed under [Tested on](#tested-on) and
previously reported to work on the hardware in
[docs/hardware-compatibility.md](docs/hardware-compatibility.md), but should
not be assumed safe on other machines without ACPI confirmation. Since v0.2.1
the installer prefers a fixed-purpose C helper and uses `busybox devmem` only
as a fallback. The proper final solution is a kernel driver quirk or firmware
method, not permanent arbitrary userspace physical memory access — see
[docs/upstream-plan.md](docs/upstream-plan.md) and
[kernel-patch/NOTES.md](kernel-patch/NOTES.md) for the intended direction.

## Credits and licence

**MIT.** This started as [kcamporacosta](https://github.com/kcamporacosta)'s
reverse-engineering and workaround for this exact bug; their original
repository has since been removed from GitHub, so this one carries the work
forward under the same license (see [LICENSE](LICENSE)). All of the ACPI
reverse engineering, the original EC-write helper, the sync daemon design, and
the v0.1.0-v0.2.1 hardening are theirs.

**Added in v0.3.0** (by Mirco Giorgi):

- The actual bug fix: the EC register's native range is 0-200, not 0-100 —
  `omen-ec-write` silently clamped every write to 100, so `omen-brightness
  100` only ever reached ~50% of true panel brightness. See
  [CHANGELOG.md](CHANGELOG.md) for the full v0.3.0 notes.
- Switched the default sync source to `intel_backlight`, since
  `nvidia_wmi_ec_backlight` is known to accept writes that never reach the
  panel on this hardware.
- `install.sh --fix-bootloader`, including GRUB support alongside the
  original systemd-boot handling.

## Contributing

Issues and pull requests are welcome, especially compatibility reports from
other HP OMEN Max owners — a confirmed second machine is worth a lot given how
model/firmware-specific the validated register is.

## Support

If this project saved you the trouble of writing it yourself, you can
support it via [GitHub Sponsors](https://github.com/sponsors/mirco-g01) or
[Ko-fi](https://ko-fi.com/mircog01). Entirely optional — issues and PRs are
just as welcome either way.

## Contact

Open an issue for anything hardware- or bug-specific — it leaves the answer
where the next affected owner will find it. Include your exact model
(`cat /sys/class/dmi/id/product_name`), kernel version, which backlight
sources exist under `/sys/class/backlight`, and whether direct writes to
`0xFD400CF5` change your panel brightness.

## Disclaimer

Provided as-is, at your own risk. Nobody here is responsible for damage to
your hardware.
