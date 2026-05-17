# Secondary GPU (RTX 2060) bound to vfio-pci for Windows VM passthrough.
#
# After install, find IDs:
#   lspci -nn | grep -i nvidia
# Example line:  ... GeForce RTX 2060 12GB [10de:1f03]
# Use vendor:device IDs for BOTH the passthrough GPU and its HDMI/DP audio function.
# Host GPU (e.g. RTX 5070 at 10de:2f04) must NOT be listed here.
#
# Also check IOMMU groups:
#   find /sys/kernel/iommu_groups/ -type l | sort -V

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.vfioPassthrough;
in
{
  options.custom.vfioPassthrough = {
    enable = lib.mkEnableOption "VFIO PCI passthrough for secondary NVIDIA GPU";

    gpuIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10de:1f03" # RTX 2060 12GB (TU106) — Arch desktop @ 04:00.0
        "10de:10f9" # RTX 2060 HDMI/DP audio — Arch desktop @ 04:00.1
      ];
      example = [
        "10de:1f03"
        "10de:10f9"
      ];
      description = "PCI vendor:device IDs to bind to vfio-pci (GPU + audio).";
    };

    hideNvidiaFromHost = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Prevent the host NVIDIA driver from claiming the passthrough GPU.
        Required when the 2060 shares the machine with a host 50-series card.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "vfio"
      "vfio_pci"
      "vfio_iommu_type1"
    ];

    boot.extraModprobeConfig = ''
      options vfio-pci ids=${lib.concatStringsSep ",", cfg.gpuIds}
      ${lib.optionalString cfg.hideNvidiaFromHost ''
        softdep nvidia pre: vfio-pci
        softdep nvidia_drm pre: vfio-pci
        softdep nvidia_modeset pre: vfio-pci
      ''}
    '';

    # Isolate passthrough devices from host drivers early
    boot.blacklist = lib.optionals cfg.hideNvidiaFromHost [
      "nouveau"
    ];

    boot.initrd.kernelModules = [
      "vfio_pci"
    ];

    # Helps avoid BAR assignment issues with NVIDIA passthrough
    boot.kernelParams = [
      "vfio_iommu_type1.allow_unsafe_interrupts=1"
    ];

    virtualisation.kvmgt.enable = false;
  };

  custom.vfioPassthrough.enable = lib.mkDefault true;
}
