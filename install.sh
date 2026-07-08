#!/usr/bin/env bash
set -euo pipefail

PROJECT="HP OMEN Max Linux brightness fix"
VERSION="0.2.1"
DEFAULT_REG="0xFD400CF5"
DEFAULT_SOURCE="/sys/class/backlight/acpi_video0"
INSTALL_PREFIX="/usr/local"
LIBEXEC_DIR="${INSTALL_PREFIX}/libexec/omen-backlight"
CONFIG_DIR="/etc/omen-backlight"
SYSTEMD_UNIT="/etc/systemd/system/omen-backlight-sync.service"

log() { echo "[install] $*"; }
warn() { echo "[warning] $*" >&2; }
fail() { echo "[error] $*" >&2; exit 1; }

usage() {
  cat <<USAGE
$PROJECT installer v$VERSION

Usage:
  sudo ./install.sh [--force] [--dry-run]

Options:
  --force    allow install on unverified HP/OMEN DMI data
  --dry-run  run checks only, do not install files
USAGE
}

FORCE="${OMEN_FORCE_INSTALL:-0}"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
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

if [[ ! -e "$DEFAULT_SOURCE/brightness" ]]; then
  warn "Default slider source not found: $DEFAULT_SOURCE"
  warn "The service can still be configured later in $CONFIG_DIR/env"
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
OMEN_BACKLIGHT_SOURCE=${DEFAULT_SOURCE}
OMEN_BACKLIGHT_MIN=5
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
