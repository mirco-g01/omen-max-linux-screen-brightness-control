# Release packaging notes

Recommended GitHub release asset name:

```text
hp-omen-max-linux-brightness-fix-v0.1.0.tar.gz
```

Install from a release archive:

```bash
tar -xzf hp-omen-max-linux-brightness-fix-v0.1.0.tar.gz
cd hp-omen-max-linux-brightness-fix-v0.1.0
sudo dnf install busybox
sudo ./install.sh
```

Uninstall:

```bash
sudo ./uninstall.sh
```

Current status: userspace workaround. This is not an upstream kernel fix.
