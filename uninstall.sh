#!/usr/bin/env bash
set -euo pipefail

log() { echo "[uninstall] $*"; }
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo ./uninstall.sh" >&2; exit 1; }

systemctl disable --now omen-backlight-sync.service 2>/dev/null || true
rm -f /etc/systemd/system/omen-backlight-sync.service
systemctl daemon-reload

rm -f /usr/local/bin/omen-brightness
rm -f /usr/local/bin/omen-brightness-step
rm -f /usr/local/bin/omen-backlight-sync
rm -rf /usr/local/libexec/omen-backlight

log "Leaving /etc/omen-backlight in place for audit/reinstall. Remove it manually if desired: sudo rm -rf /etc/omen-backlight"
log "Uninstalled."
