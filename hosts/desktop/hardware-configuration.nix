# Replace this file after `nixos-generate-config` on the installer.
# On a live USB, from this repo:
#   sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
#
# At minimum you need boot.initrd, fileSystems, swapDevices, and networking.

{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-amd"
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
  ];
  boot.extraModulePackages = [ ];

  # --- EDIT: your root (and boot if separate) filesystems ---
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-ROOT-UUID";
    fsType = "ext4"; # or btrfs, xfs, etc.
  };

  # boot.loader.efi.efiSysMount = "/boot/efi";
  # fileSystems."/boot/efi" = {
  #   device = "/dev/disk/by-uuid/REPLACE-EFI-UUID";
  #   fsType = "vfat";
  # };

  # swapDevices = [ { device = "/dev/disk/by-uuid/REPLACE-SWAP-UUID"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
