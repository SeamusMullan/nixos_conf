# Secondary GPU (RTX 2060) bound to vfio-pci for Windows VM passthrough.
#
# After install, find IDs:
#   lspci -nn | grep -i nvidia
# Example line:  ... NVIDIA Corporation GA106 [GeForce RTX 2060] [10de:1f08]
# Use the 10de:1f08 style IDs for BOTH the GPU and its HDMI/DP audio function.
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
        "10de:1f08" # RTX 2060 — REPLACE with lspci -nn output
        "10de:10f9" # RTX 2060 audio — REPLACE
      ];
      example = [
        "10de:1f08"
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
