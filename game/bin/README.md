# Godot binary (local install)

Place the **Godot 4.6** editor binary here (not committed). On Linux ARM64 (e.g. Raspberry Pi):

```bash
cd game/bin
curl -fsSL -o Godot_v4.6-stable_linux.arm64.zip \
  https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.arm64.zip
unzip Godot_v4.6-stable_linux.arm64.zip
chmod +x Godot_v4.6-stable_linux.arm64
ln -sf Godot_v4.6-stable_linux.arm64 godot
```

From the repo root, run the client:

```bash
./game/bin/godot --path game/
```

First run (or after cloning): import assets once:

```bash
./game/bin/godot --path game/ --import
```
