#!/usr/bin/env bash
#
# install.sh — bootstrap and install this NixOS flake on the target desktop PC.
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ WHERE TO RUN                                                                │
# ├─────────────────────────────────────────────────────────────────────────────┤
# │ • NixOS live USB (or installed NixOS), on the machine you are setting up.   │
# │ • NOT on macOS — use GitHub Actions or a Linux VM to only *build* there.    │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ BEFORE FIRST INSTALL (live USB)                                             │
# ├─────────────────────────────────────────────────────────────────────────────┤
# │ 1. Partition & format disks (e.g. gdisk, parted).                           │
# │ 2. Mount root at /mnt (and EFI at /mnt/boot/efi if separate).             │
# │ 3. git clone <this-repo> && cd nixos_conf                                   │
# │ 4. sudo ./install.sh              # interactive install                     │
# │    sudo ./install.sh --build-only # verify build without installing         │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ AFTER NIXOS IS INSTALLED (from a clone on the running system)              │
# ├─────────────────────────────────────────────────────────────────────────────┤
# │   sudo ./install.sh switch        # apply config changes                    │
# │   sudo ./install.sh build         # compile only                            │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# See README.md and conversation.md for VFIO, NVIDIA, and audio notes.

set -euo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
FLAKE_HOST="desktop"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="${REPO_ROOT}/hosts/desktop"
HARDWARE_FILE="${HOST_DIR}/hardware-configuration.nix"
LOCAL_EXAMPLE="${HOST_DIR}/local.nix.example"
LOCAL_FILE="${HOST_DIR}/local.nix"
HOST_DEFAULT="${HOST_DIR}/default.nix"
VFIO_MODULE="${REPO_ROOT}/modules/gpu/vfio-passthrough.nix"
INSTALL_ROOT="/mnt"
SKIP_CONFIRM=0
SKIP_FLAKE_UPDATE=0
SKIP_VFIO_PROMPT=0
FORCE_HARDWARE=0
PLACEHOLDER_UUID="REPLACE-ROOT-UUID"

# ── logging ────────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!!>\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
die()   { err "$@"; exit 1; }

# ── usage ──────────────────────────────────────────────────────────────────────
usage() {
  sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
  cat <<EOF

Commands:
  install       First-time install to \$INSTALL_ROOT (default: /mnt). Live USB only.
  switch        Apply flake on a running NixOS system (nixos-rebuild switch).
  build         Build system closure only (no activate / no install).
  hardware      Regenerate hosts/desktop/hardware-configuration.nix only.
  help          Show this message.

Options:
  -y, --yes                 Skip confirmation prompts (except destructive install).
  --no-flake-update         Do not run 'nix flake update' before build.
  --skip-vfio-prompt        Do not ask for RTX 2060 PCI IDs.
  --regenerate-hardware     Always run nixos-generate-config (overwrite after backup).
  --root PATH               Install target root (default: /mnt).
  -h, --help                Show help.

Examples:
  sudo ./install.sh --build-only
  sudo ./install.sh hardware
  sudo ./install.sh install
  sudo ./install.sh switch -y

EOF
}

# ── guards ─────────────────────────────────────────────────────────────────────
require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    die "This script must run on Linux (NixOS live USB or installed system). Current: $(uname -s)"
  fi
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root: sudo $0 $*"
  fi
}

require_nix() {
  command -v nix >/dev/null 2>&1 || die "'nix' not found. Use the NixOS installer image or install Nix."
}

require_flake() {
  [[ -f "${REPO_ROOT}/flake.nix" ]] || die "flake.nix not found. Run from the repo root (got: ${REPO_ROOT})"
}

confirm() {
  local msg="$1"
  if [[ "$SKIP_CONFIRM" -eq 1 ]]; then
    return 0
  fi
  printf '%s [y/N] ' "$msg"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── setup helpers ──────────────────────────────────────────────────────────────
flakes_enabled() {
  if [[ "${NIX_CONFIG:-}" == *nix-command* ]] && [[ "${NIX_CONFIG:-}" == *flakes* ]]; then
    return 0
  fi
  if [[ -f /etc/nix/nix.conf ]] && grep -q 'experimental-features.*nix-command' /etc/nix/nix.conf 2>/dev/null; then
    return 0
  fi
  if nix config show experimental-features 2>/dev/null | grep -q nix-command; then
    return 0
  fi
  return 1
}

ensure_experimental_features() {
  local features='experimental-features = nix-command flakes'

  if flakes_enabled; then
    return 0
  fi

  mkdir -p /etc/nix 2>/dev/null || true
  if { [[ ! -f /etc/nix/nix.conf ]] || [[ -w /etc/nix/nix.conf ]]; } 2>/dev/null; then
    info "Enabling nix flakes in /etc/nix/nix.conf"
    cat >>/etc/nix/nix.conf <<EOF
${features}
EOF
    return 0
  fi

  info "Enabling nix flakes via NIX_CONFIG (/etc/nix is read-only on NixOS)"
  if [[ -n "${NIX_CONFIG:-}" ]]; then
    export NIX_CONFIG="${NIX_CONFIG}; ${features}"
  else
    export NIX_CONFIG="${features}"
  fi
}

flake_update() {
  if [[ "$SKIP_FLAKE_UPDATE" -eq 1 ]]; then
    info "Skipping nix flake update (--no-flake-update)"
    return 0
  fi
  info "Updating flake lock file (nix flake update)"
  (cd "$REPO_ROOT" && nix flake update --accept-flake-config)
}

ensure_local_nix() {
  if [[ -f "$LOCAL_FILE" ]]; then
    info "Found existing ${LOCAL_FILE}"
  else
    if [[ ! -f "$LOCAL_EXAMPLE" ]]; then
      warn "No local.nix.example — skipping local.nix setup"
      return 0
    fi
    cp "$LOCAL_EXAMPLE" "$LOCAL_FILE"
    info "Created ${LOCAL_FILE} from local.nix.example (edit for your machine)"
  fi

  if grep -q './local.nix' "$HOST_DEFAULT" 2>/dev/null; then
    info "hosts/desktop/default.nix already imports local.nix"
  else
    info "Adding './local.nix' import to hosts/desktop/default.nix"
    sed -i.bak '/imports = \[/a\    ./local.nix' "$HOST_DEFAULT"
    info "Backup saved as hosts/desktop/default.nix.bak"
  fi
}

hardware_has_placeholder() {
  grep -q "$PLACEHOLDER_UUID" "$HARDWARE_FILE" 2>/dev/null
}

generate_hardware_config() {
  local force="${1:-0}"
  info "Generating ${HARDWARE_FILE}"
  if [[ -f "$HARDWARE_FILE" ]] && ! hardware_has_placeholder && [[ "$force" -ne 1 ]]; then
    if ! confirm "Overwrite existing hardware-configuration.nix?"; then
      info "Keeping existing hardware-configuration.nix"
      return 0
    fi
  fi
  if [[ -f "$HARDWARE_FILE" ]]; then
    cp "$HARDWARE_FILE" "${HARDWARE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    info "Backed up previous hardware-configuration.nix"
  fi
  nixos-generate-config --show-hardware-config >"$HARDWARE_FILE"
  info "Wrote ${HARDWARE_FILE}"
  if hardware_has_placeholder; then
    warn "File may still contain placeholders — ensure fileSystems / boot entries match your mounts."
  fi
}

generate_hardware_config_if_needed() {
  local mode="$1" # install | build | switch
  if [[ "$FORCE_HARDWARE" -eq 1 ]] || [[ "$mode" == "install" ]] || hardware_has_placeholder; then
    generate_hardware_config "$FORCE_HARDWARE"
  else
    info "Keeping hardware-configuration.nix (use: $0 hardware  or  --regenerate-hardware)"
  fi
}

show_nvidia_devices() {
  if command -v lspci >/dev/null 2>&1; then
    info "NVIDIA devices (set VFIO IDs for the RTX 2060, not the host 50-series):"
    lspci -nn | grep -i nvidia || warn "No NVIDIA devices found via lspci"
  else
    warn "lspci not available"
  fi
}

prompt_vfio_ids() {
  if [[ "$SKIP_VFIO_PROMPT" -eq 1 ]]; then
    return 0
  fi

  show_nvidia_devices
  echo
  warn "VFIO passthrough uses placeholder IDs in modules/gpu/vfio-passthrough.nix"
  warn "You should set the RTX 2060 GPU + its HDMI/DP audio function in local.nix:"
  echo
  echo "  custom.vfioPassthrough.gpuIds = [ \"10de:xxxx\" \"10de:yyyy\" ];"
  echo
  if ! confirm "Open local.nix in \$EDITOR after setup to set VFIO IDs?"; then
    return 0
  fi
  ensure_local_nix
  "${EDITOR:-nano}" "$LOCAL_FILE" || true
}

check_install_mounts() {
  if [[ ! -d "${INSTALL_ROOT}" ]]; then
    die "Install root ${INSTALL_ROOT} does not exist. Partition, format, and mount your root filesystem there."
  fi
  if [[ ! -f "${INSTALL_ROOT}/etc/machine-id" ]] && [[ ! -d "${INSTALL_ROOT}/nix" ]] && [[ -z "$(ls -A "${INSTALL_ROOT}" 2>/dev/null)" ]]; then
    warn "${INSTALL_ROOT} looks empty — is the root filesystem mounted?"
    confirm "Continue anyway?" || die "Aborted."
  fi
  info "Install target root: ${INSTALL_ROOT}"
}

run_build() {
  info "Building .#${FLAKE_HOST} (this can take a long time on first run)"
  (cd "$REPO_ROOT" && nixos-rebuild build --flake ".#${FLAKE_HOST}" --accept-flake-config)
  info "Build finished successfully"
}

run_switch() {
  info "Switching system to .#${FLAKE_HOST}"
  (cd "$REPO_ROOT" && nixos-rebuild switch --flake ".#${FLAKE_HOST}" --accept-flake-config)
  info "Switch complete. Log out and back in if Home Manager / desktop session changed."
}

run_install() {
  check_install_mounts
  echo
  warn "This will run: nixos-install --flake .#${FLAKE_HOST} --root ${INSTALL_ROOT}"
  warn "Ensure the correct disk is mounted at ${INSTALL_ROOT}. All data on that disk may be overwritten."
  echo
  confirm "Proceed with nixos-install?" || die "Aborted."

  info "Installing to ${INSTALL_ROOT}"
  (cd "$REPO_ROOT" && nixos-install --flake ".#${FLAKE_HOST}" --root "$INSTALL_ROOT" --no-root-passwd)

  echo
  info "If install succeeded, set the root password:"
  echo "  sudo nixos-enter --root ${INSTALL_ROOT} -- passwd root"
  echo "  sudo nixos-enter --root ${INSTALL_ROOT} -- passwd sarah"
  echo
  info "Unmount and reboot:"
  echo "  sudo umount -R ${INSTALL_ROOT} && sudo reboot"
}

# ── main flow ──────────────────────────────────────────────────────────────────
run_common_setup() {
  local mode="${1:-install}"
  require_linux
  require_root
  require_nix
  require_flake
  ensure_experimental_features
  cd "$REPO_ROOT"
  info "Repository: ${REPO_ROOT}"
  ensure_local_nix
  generate_hardware_config_if_needed "$mode"
  prompt_vfio_ids
  flake_update
}

main() {
  local cmd="install"

  # Parse global options and command
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -y|--yes) SKIP_CONFIRM=1; shift ;;
      --no-flake-update) SKIP_FLAKE_UPDATE=1; shift ;;
      --skip-vfio-prompt) SKIP_VFIO_PROMPT=1; shift ;;
      --regenerate-hardware) FORCE_HARDWARE=1; shift ;;
      --root) INSTALL_ROOT="$2"; shift 2 ;;
      --build-only) cmd="build"; shift ;;
      install|switch|build|hardware|help)
        cmd="$1"
        shift
        ;;
      *)
        die "Unknown argument: $1 (try --help)"
        ;;
    esac
  done

  case "$cmd" in
    help) usage; exit 0 ;;
    hardware)
      require_linux
      require_root
      require_nix
      require_flake
      generate_hardware_config 1
      show_nvidia_devices
      exit 0
      ;;
    build)
      run_common_setup build
      run_build
      ;;
    switch)
      run_common_setup switch
      run_build
      run_switch
      ;;
    install)
      run_common_setup install
      run_build
      run_install
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
