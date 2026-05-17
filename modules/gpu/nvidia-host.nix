# Primary GPU: RTX 50-series (Blackwell). Uses the newest production driver in nixpkgs.
# If the GPU is not detected after switch, try:
#   hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;
# and ensure allowUnfree is set (it is, in this module).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.nvidiaHost;
in
{
  options.custom.nvidiaHost = {
    enable = lib.mkEnableOption "NVIDIA host driver for primary GPU";
    useOpenKernelModules = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use NVIDIA open kernel modules (enable if production fails on 50-series).";
    };
    driverPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Override driver package; null = production from kernelPackages.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = cfg.useOpenKernelModules;
      nvidiaSettings = true;

      package =
        if cfg.driverPackage != null then
          cfg.driverPackage
        else
          config.boot.kernelPackages.nvidiaPackages.production;
    };

    # RTX 50 / recent cards often need a recent kernel
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    environment.systemPackages = with pkgs; [ nvidia-settings ];
  };

  custom.nvidiaHost.enable = lib.mkDefault true;
}
