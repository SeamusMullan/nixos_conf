# nixos_conf

NixOS flake + Home Manager config for **sarah**'s desktop PC.

- **OS:** NixOS (unstable), **DE:** X11 + i3 + LightDM  
- **Hardware:** Ryzen 7 5800X, RTX 50-series (host), RTX 2060 (VFIO passthrough), Focusrite Scarlett  
- **User:** `sarah` (no Bluetooth)

## Quick start

**On the target PC (NixOS live USB):** partition disks, mount root at `/mnt`, then:

```bash
git clone <your-repo-url> nixos_conf && cd nixos_conf
sudo ./install.sh              # full guided install
sudo ./install.sh --build-only # verify build only (no disk install)
```

`install.sh` will: enable flakes, create `local.nix` from the example, import it in `hosts/desktop/default.nix`, regenerate `hardware-configuration.nix`, optionally prompt for VFIO notes, update the flake lock, build, and run `nixos-install`.

**On an already-installed system:**

```bash
cd nixos_conf
sudo ./install.sh switch
```

Run `sudo ./install.sh help` for all commands and flags.

Manual equivalent (if you prefer):

```bash
sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
# Set VFIO PCI IDs — see GPU section below
sudo nixos-install --flake .#desktop --root /mnt   # first install
sudo nixos-rebuild switch --flake .#desktop        # later updates
```

Machine-specific overrides: `install.sh` creates `hosts/desktop/local.nix` automatically; edit it for VFIO IDs and other options.

---

## Repo layout

| Path | Purpose |
|------|---------|
| `flake.nix` | Flake inputs, `nixosConfigurations.desktop` |
| `hosts/desktop/` | Host config + `hardware-configuration.nix` |
| `home/sarah/` | Home Manager (i3, kitty, zsh, ML Python, bun, …) |
| `modules/` | Feature modules (GPU, audio, dev, creative, …) |
| `docs/` | Extra notes (e.g. VM GPU passthrough XML example) |

---

## What's installed

### Desktop & daily use

| Item | Module |
|------|--------|
| i3, LightDM, picom, rofi, kitty, zsh | `modules/desktop/i3-x11.nix`, `home/sarah/` |
| Firefox, Steam, git, curl, wget, vim, neovim | `hosts/desktop/default.nix` |
| **Vesktop**, **Element** (Matrix), **Signal**, **LocalSend**, Telegram, Slack | `modules/desktop/communications.nix` |

### Audio (work + plugins)

| Item | Module |
|------|--------|
| PipeWire (low latency), JACK, Scarlett USB udev | `modules/audio/pro-audio.nix` |
| REAPER, Wine + WineASIO, yabridge, LV2/CLAP toolchain, Carla, jalv | `modules/audio/plugin-dev.nix` |
| helvum, qpwgraph, pavucontrol | pro-audio / plugin-dev |

### Creative (3D + games)

| Item | Module |
|------|--------|
| Blender, GIMP, Krita, FFmpeg, FreeCAD, Meshlab | `modules/creative/render-gamedev.nix` |
| Godot 4 + export templates, Tiled, LDtk, Renderdoc, Vulkan tools | same |
| MangoHud, GameMode, Lutris | same |

### Development

| Item | Module |
|------|--------|
| **Languages:** C/C++, Python, bun + Node 22, Java 21, Rust, Go, Lua, nasm/yasm | `modules/dev/languages.nix` |
| **ML/CUDA:** PyTorch env, cudatoolkit, cudnn, Docker + NVIDIA toolkit | `modules/dev/cuda-ml.nix`, `home/sarah/ml-python.nix` |
| direnv, bun (Home Manager) | `home/sarah/languages.nix` |

### GPU & VMs

| Item | Module |
|------|--------|
| NVIDIA production driver (RTX 50-series host) | `modules/gpu/nvidia-host.nix` |
| VFIO passthrough (RTX 2060 → Windows VM) | `modules/gpu/vfio-passthrough.nix` |
| libvirt, virt-manager, OVMF | `modules/virtualization/libvirt-vfio.nix` |

---

## Important notes (not automatic)

### Must configure before first boot

1. **`hosts/desktop/hardware-configuration.nix`** — Template UUIDs are placeholders. Regenerate with `nixos-generate-config` on the real machine.  
2. **VFIO PCI IDs** — Edit `modules/gpu/vfio-passthrough.nix` or `local.nix`. Run `lspci -nn | grep -i nvidia` and set **both** the 2060 GPU and its **audio** function IDs. Defaults (`10de:1f08`, etc.) are examples only.  
3. **Timezone** — Default `Europe/London` in `hosts/desktop/default.nix`; change if needed.  
4. **Git identity** — Set name/email in `home/sarah/default.nix`.

### NVIDIA (RTX 50-series)

- Uses `nvidiaPackages.production` + `linuxPackages_latest`.  
- If the GPU is not detected after rebuild, try in `local.nix`:
  - `custom.nvidiaHost.driverPackage = config.boot.kernelPackages.nvidiaPackages.beta;`
  - `custom.nvidiaHost.useOpenKernelModules = true;`  
- **Blender / ML:** Enable CUDA or OptiX in app preferences; verify with `nvidia-smi` and `ml-check` (see below).

### Windows VM (RTX 2060 passthrough)

- Needs **IOMMU** on in BIOS, display on the **50-series** for the host.  
- Create VM in virt-manager with **OVMF (UEFI)**; attach GPU + audio via PCI passthrough (`docs/vm-windows-gpu.xml.example`).  
- Guest needs its own monitor, **dummy HDMI plug**, or Looking Glass — not magic out of the box.  
- NVIDIA VMs may hit **error 43**; may need VBIOS dump / vendor-reset tweaks.

### Docker + GPU (ML containers)

- On recent NixOS, prefer:  
  `docker run --device nvidia.com/gpu=all ...`  
- Legacy `--gpus all` is often **broken** on NixOS; see [nixpkgs issues](https://github.com/NixOS/nixpkgs/issues/419597).

### Audio / plugin dev

- **Scarlett:** Works with PipeWire; use **qpwgraph** or **helvum** to route. For lower latency: `custom.proAudio.quantum = 128` in `local.nix`.  
- **REAPER:** Installed; you must set LV2/CLAP/VST scan paths in Preferences.  
- **FL Studio / Ableton:** Wine + WineASIO are installed; **prefixes and installers are not set up.** See `/etc/plugin-dev/README` on the machine after install.  
- **yabridge:** For Windows **plugins** in native Linux DAWs — run `yabridgectl add` / `sync` after you have a Wine prefix with plugins.

### Messaging

- **Signal:** Link phone on first launch like any other platform.  
- **LocalSend:** Usually works on LAN; if devices do not appear, check firewall / same subnet.  
- **Matrix:** Default client is **Element**; switch to Fractal/Nheko via `custom.communications.matrixClient` in `local.nix`.

### Python: two environments

| Use | Where |
|-----|--------|
| Coursework / scripts | System `python3`, `uv venv` (`modules/dev/languages.nix`) |
| ML / PyTorch / Jupyter | Home Manager ML env (`home/sarah/ml-python.nix`) |

Test ML GPU: `ml-check`  
Start Jupyter: `jlab`

### Languages

- **Rust/Go/Java** come from nixpkgs (fixed versions). For `rustup` + nightly, ask to add it.  
- **bun** is the preferred JS runtime; Node 22 is also installed for tooling that needs it.  
- **Java:** Default JDK **21**; use `custom.languages.javaVersion = "17"` for older courses.

### BIOS checklist (5800X + dual NVIDIA)

- SVM (AMD-V) **on**  
- IOMMU **on**  
- Above 4G decoding **on** (passthrough)  
- Primary monitor on the **50-series**

---

## Useful commands

```bash
# Rebuild
sudo nixos-rebuild switch --flake .#desktop

# GPU
nvidia-smi
lspci -nn | grep -i nvidia
lspci -k | grep -A3 -i nvidia    # vfio-pci vs nvidia driver

# ML
ml-check

# Plugin testing
jalv.gtk3 ./plugin.lv2
clap-validator validate ./plugin.clap

# Audio routing
qpwgraph
helvum

# IOMMU groups (passthrough)
find /sys/kernel/iommu_groups/ -type l | sort -V
```

---

## Customization cheat sheet

Copy `hosts/desktop/local.nix.example` → `local.nix` and import it. Examples:

```nix
custom.vfioPassthrough.gpuIds = [ "10de:xxxx" "10de:yyyy" ];
custom.nvidiaHost.driverPackage = config.boot.kernelPackages.nvidiaPackages.beta;
custom.proAudio.sampleRate = 96000;
custom.proAudio.quantum = 128;
custom.communications.matrixClient = "fractal";
custom.languages.javaVersion = "17";
custom.pluginDev.enableVst3Sdk = true;
custom.renderGamedev.enableUnityHub = true;
custom.cudaMl.enableNsight = true;
```

---

## Hostname & flake output

- **Configuration name:** `desktop`  
- **Build:** `nixos-rebuild switch --flake .#desktop`
