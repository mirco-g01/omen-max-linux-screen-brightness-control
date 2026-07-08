#!/usr/bin/env bash
set -euo pipefail

PROJECT="HP OMEN Max Linux brightness fix"
REQUIRED_VENDOR="HP"
DEFAULT_REG="0xFD400CF5"
DEFAULT_SOURCE="/sys/class/backlight/acpi_video0"

log() { echo "[install] $*"; }
warn() { echo "[warning] $*" >&2; }
fail() { echo "[error] $*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  fail "Run as root: sudo ./install.sh"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

manufacturer="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

log "$PROJECT"
log "Detected system: ${manufacturer:-unknown} ${product:-unknown}"

if [[ "$manufacturer" != *"$REQUIRED_VENDOR"* ]]; then
  warn "This does not look like an HP system. Refusing automatic install."
  warn "Set OMEN_FORCE_INSTALL=1 only if you know exactly what you are doing."
  [[ "${OMEN_FORCE_INSTALL:-0}" == "1" ]] || exit 1
fi

if [[ "$product" != *"OMEN"* && "${OMEN_FORCE_INSTALL:-0}" != "1" ]]; then
  warn "This does not look like an HP OMEN system. Refusing automatic install."
  warn "Set OMEN_FORCE_INSTALL=1 only after verifying the ACPI register on your machine."
  exit 1
fi

command -v busybox >/dev/null 2>&1 || fail "busybox is required. Install it first, e.g. sudo dnf install busybox"
[[ -e "$DEFAULT_SOURCE/brightness" ]] || warn "Default slider source not found: $DEFAULT_SOURCE"

log "Installing scripts..."
install -m 0755 scripts/omen-brightness /usr/local/bin/omen-brightness
install -m 0755 scripts/omen-brightness-step /usr/local/bin/omen-brightness-step
install -m 0755 scripts/omen-backlight-sync /usr/local/bin/omen-backlight-sync

log "Installing systemd service..."
install -m 0644 systemd/omen-backlight-sync.service /etc/systemd/system/omen-backlight-sync.service

log "Installing configuration..."
install -d -m 0755 /etc/omen-backlight
cat > /etc/omen-backlight/env <<ENVEOF
# HP OMEN Max Linux brightness workaround configuration
OMEN_BACKLIGHT_REG=${DEFAULT_REG}
OMEN_BACKLIGHT_SOURCE=${DEFAULT_SOURCE}
OMEN_BACKLIGHT_MIN=5
OMEN_BACKLIGHT_MAX=100
OMEN_BACKLIGHT_POLL_INTERVAL=0.10
ENVEOF

# Add EnvironmentFile if not already present.
if ! grep -q '^EnvironmentFile=/etc/omen-backlight/env' /etc/systemd/system/omen-backlight-sync.service; then
  sed -i '/^ExecStart=/i EnvironmentFile=/etc/omen-backlight/env' /etc/systemd/system/omen-backlight-sync.service
fi

systemctl daemon-reload
systemctl enable --now omen-backlight-sync.service

log "Installed."
log "Check status with: systemctl status omen-backlight-sync.service"
log "Manual test: sudo omen-brightness 30 && sudo omen-brightness 80"
