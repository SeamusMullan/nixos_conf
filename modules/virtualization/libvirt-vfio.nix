{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.libvirtVfio;
in
{
  options.custom.libvirtVfio = {
    enable = lib.mkEnableOption "libvirt/QEMU with OVMF for GPU passthrough VMs";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
      qemu.runAsRoot = false;
      qemu.swtpm.enable = true;
    };

    virtualisation.spiceUSBRedirection.enable = true;

    environment.systemPackages = with pkgs; [
      virt-manager
      qemu
      OVMF
      virtiofsd
      edk2
    ];

    # Example VM XML snippets are in docs/vm-windows.xml (create separately if needed)
  };

  custom.libvirtVfio.enable = lib.mkDefault true;
}
