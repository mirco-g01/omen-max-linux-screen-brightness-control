#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./uninstall.sh" >&2
  exit 1
fi

systemctl disable --now omen-backlight-sync.service 2>/dev/null || true
rm -f /etc/systemd/system/omen-backlight-sync.service
rm -f /usr/local/bin/omen-brightness /usr/local/bin/omen-brightness-step /usr/local/bin/omen-backlight-sync
rm -rf /etc/omen-backlight
systemctl daemon-reload

echo "Uninstalled HP OMEN Max Linux brightness workaround."
