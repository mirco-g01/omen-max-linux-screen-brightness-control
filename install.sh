#!/usr/bin/env bash
set -euo pipefail

PROJECT="HP OMEN Max Linux brightness fix"
VERSION="0.3.0"
DEFAULT_REG="0xFD400CF5"
INSTALL_PREFIX="/usr/local"
LIBEXEC_DIR="${INSTALL_PREFIX}/libexec/omen-backlight"
CONFIG_DIR="/etc/omen-backlight"
SYSTEMD_UNIT="/etc/systemd/system/omen-backlight-sync.service"

log() { echo "[install] $*"; }
warn() { echo "[warning] $*" >&2; }
fail() { echo "[error] $*" >&2; exit 1; }

# Preference order for the OS-visible backlight device to mirror.
# intel_backlight (native i915/eDP PWM) comes first: on HP OMEN Max /
# Advanced Optimus hardware the WMI-based nvidia_wmi_ec_backlight device is
# known to accept writes that never reach the panel (the firmware's
# brightness AML method recomputes the EC register from an Intel OpRegion
# field the graphics driver never writes, so it always resets to a fixed
# value). intel_backlight only exists when the kernel is booted with
# acpi_backlight=native; see fix_bootloader_backlight() below.
detect_source() {
  local dev
  for dev in \
    /sys/class/backlight/intel_backlight \
    /sys/class/backlight/nvidia_wmi_ec_backlight \
    /sys/class/backlight/acpi_video0 \
    /sys/class/backlight/acpi_video1; do
    if [[ -r "$dev/brightness" && -r "$dev/max_brightness" ]]; then
      echo "$dev"
      return 0
    fi
  done
  return 1
}

# Patches a systemd-boot entry to add acpi_backlight=native (and drop the
# now-redundant/interfering i915.enable_dpcd_backlight=1, if present) so the
# kernel registers a real, physically-effective intel_backlight device
# instead of the broken WMI one. Backs up every entry it touches. No-op on
# GRUB/other bootloaders; prints manual instructions instead.
fix_bootloader_backlight() {
  if [[ ! -d /boot/loader/entries ]]; then
    warn "systemd-boot entries not found under /boot/loader/entries; cannot auto-patch."
    warn "Add 'acpi_backlight=native' to your bootloader's kernel command line manually"
    warn "(e.g. GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then regenerate grub.cfg),"
    warn "then reboot."
    return 1
  fi

  local entry patched=0
  for entry in /boot/loader/entries/*.conf; do
    [[ -f "$entry" ]] || continue
    grep -q '^options ' "$entry" || continue
    if grep -q 'acpi_backlight=native' "$entry"; then
      log "acpi_backlight=native already present in $entry"
      continue
    fi
    cp -a "$entry" "${entry}.bak.$(date +%Y%m%d%H%M%S)"
    sed -i -E 's/ ?i915\.enable_dpcd_backlight=1//; s/^(options .*)$/\1 acpi_backlight=native/' "$entry"
    log "Patched $entry (backup saved alongside). A reboot is required for this to take effect."
    patched=1
  done
  [[ "$patched" == "1" ]] || warn "No systemd-boot entry needed patching."
}

usage() {
  cat <<USAGE
$PROJECT installer v$VERSION

Usage:
  sudo ./install.sh [--force] [--dry-run] [--fix-bootloader]

Options:
  --force           allow install on unverified HP/OMEN DMI data
  --dry-run         run checks only, do not install files
  --fix-bootloader  on Advanced Optimus laptops where intel_backlight is
                    missing, auto-patch a systemd-boot entry with
                    acpi_backlight=native (backs up the entry first; requires
                    a reboot to take effect)
USAGE
}

FORCE="${OMEN_FORCE_INSTALL:-0}"
DRY_RUN=0
FIX_BOOTLOADER=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --fix-bootloader) FIX_BOOTLOADER=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $arg" ;;
  esac
done

[[ $EUID -eq 0 ]] || fail "Run as root: sudo ./install.sh"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

manufacturer="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
version="$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)"

log "$PROJECT v$VERSION"
log "Detected system: ${manufacturer:-unknown} ${product:-unknown} ${version:-}"

if [[ "$manufacturer" != *"HP"* && "$manufacturer" != *"Hewlett-Packard"* ]]; then
  warn "This does not look like an HP system."
  [[ "$FORCE" == "1" ]] || fail "Refusing install. Re-run with --force only if you validated the hardware register."
fi

if [[ "$product" != *"OMEN"* && "$FORCE" != "1" ]]; then
  warn "This does not look like an HP OMEN system."
  fail "Refusing install. Re-run with --force only if you validated the hardware register."
fi

DETECTED_SOURCE="$(detect_source || true)"
if [[ -n "$DETECTED_SOURCE" ]]; then
  log "Detected slider source: $DETECTED_SOURCE"
else
  warn "No usable /sys/class/backlight source found yet."
  warn "The service auto-detects at every start; configure OMEN_BACKLIGHT_SOURCE"
  warn "in $CONFIG_DIR/env manually if it still doesn't pick the right one."
fi

if [[ ! -e /sys/class/backlight/intel_backlight ]]; then
  warn "No native 'intel_backlight' device found."
  warn "On HP OMEN Max / Advanced Optimus laptops the WMI-based backlight"
  warn "device (nvidia_wmi_ec_backlight) is known to accept writes that never"
  warn "reach the panel. The fix is booting with 'acpi_backlight=native' on"
  warn "the kernel command line."
  if [[ "$FIX_BOOTLOADER" == "1" ]]; then
    fix_bootloader_backlight
  else
    warn "Re-run with --fix-bootloader to patch a systemd-boot entry automatically,"
    warn "or add acpi_backlight=native to your bootloader config manually, then reboot."
  fi
fi

if [[ ! -r /dev/mem || ! -w /dev/mem ]]; then
  warn "/dev/mem is not readable/writable by root. The helper may fail on this kernel."
fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "Dry run complete. No files were installed."
  exit 0
fi

log "Installing scripts..."
install -d -m 0755 "${INSTALL_PREFIX}/bin"
install -m 0755 scripts/omen-brightness "${INSTALL_PREFIX}/bin/omen-brightness"
install -m 0755 scripts/omen-brightness-step "${INSTALL_PREFIX}/bin/omen-brightness-step"
install -m 0755 scripts/omen-backlight-sync "${INSTALL_PREFIX}/bin/omen-backlight-sync"

log "Installing helper..."
install -d -m 0755 "$LIBEXEC_DIR"
if command -v gcc >/dev/null 2>&1; then
  gcc -O2 -Wall -Wextra -o "$LIBEXEC_DIR/omen-ec-write" tools/omen-ec-write.c
  chmod 0755 "$LIBEXEC_DIR/omen-ec-write"
  log "Compiled helper: $LIBEXEC_DIR/omen-ec-write"
else
  warn "gcc not found; using busybox devmem fallback. Install gcc and rerun installer for the safer dedicated helper."
  command -v busybox >/dev/null 2>&1 || fail "busybox is required when gcc is unavailable. Install it first, e.g. sudo dnf install busybox"
fi

log "Installing systemd service..."
install -m 0644 systemd/omen-backlight-sync.service "$SYSTEMD_UNIT"

log "Installing configuration..."
install -d -m 0755 "$CONFIG_DIR"
if [[ -f "$CONFIG_DIR/env" ]]; then
  cp -a "$CONFIG_DIR/env" "$CONFIG_DIR/env.backup.$(date +%Y%m%d%H%M%S)"
fi
cat > "$CONFIG_DIR/env" <<ENVEOF
# HP OMEN Max Linux brightness workaround configuration
OMEN_BACKLIGHT_REG=${DEFAULT_REG}
# Required for the validated custom register used by HP OMEN Max 16-ah0xxx.
# The helper refuses custom registers unless this is explicitly enabled.
OMEN_ALLOW_CUSTOM_REG=1
OMEN_BACKLIGHT_SOURCE=${DETECTED_SOURCE}
OMEN_BACKLIGHT_MIN=0
OMEN_BACKLIGHT_MAX=100
OMEN_BACKLIGHT_STEP=10
OMEN_BACKLIGHT_POLL_INTERVAL=0.10
OMEN_BACKLIGHT_HELPER=${LIBEXEC_DIR}/omen-ec-write
ENVEOF

systemctl daemon-reload
systemctl enable --now omen-backlight-sync.service

log "Installed."
log "Status: systemctl status omen-backlight-sync.service"
log "Logs:   journalctl -u omen-backlight-sync.service -f"
log "Test:   sudo omen-brightness 30 && sudo omen-brightness 80"
