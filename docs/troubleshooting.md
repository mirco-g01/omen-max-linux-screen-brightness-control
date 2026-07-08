# Troubleshooting

## Service status

```bash
systemctl status omen-backlight-sync.service
```

## Live logs

```bash
journalctl -u omen-backlight-sync.service -f
```

## Check OS-visible backlight sources

```bash
ls /sys/class/backlight
cat /sys/class/backlight/*/brightness
cat /sys/class/backlight/*/max_brightness
```

## Check configuration

```bash
cat /etc/omen-backlight/env
```

## Manual brightness test

```bash
sudo omen-brightness 30
sudo omen-brightness 80
```

## If the slider moves but real brightness does not change

Confirm that the correct OS-visible backlight source is configured:

```bash
watch -n 0.2 'for d in /sys/class/backlight/*; do echo "$d $(cat "$d/brightness")/$(cat "$d/max_brightness")"; done'
```

Move the brightness slider or press brightness keys. Set `OMEN_BACKLIGHT_SOURCE` in `/etc/omen-backlight/env` to the device that changes.

Restart the service:

```bash
sudo systemctl restart omen-backlight-sync.service
```
