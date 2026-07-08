#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh" >&2
  exit 1
fi

install -m 0755 scripts/omen-brightness /usr/local/bin/omen-brightness
install -m 0755 scripts/omen-brightness-step /usr/local/bin/omen-brightness-step
install -m 0755 scripts/omen-backlight-sync /usr/local/bin/omen-backlight-sync
install -m 0644 systemd/omen-backlight-sync.service /etc/systemd/system/omen-backlight-sync.service
systemctl daemon-reload
systemctl enable --now omen-backlight-sync.service

echo "Installed. Check with: systemctl status omen-backlight-sync.service"
