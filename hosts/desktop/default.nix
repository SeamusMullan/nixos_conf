{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop/i3-x11.nix
    ../../modules/desktop/communications.nix
    ../../modules/gpu/nvidia-host.nix
    ../../modules/gpu/vfio-passthrough.nix
    ../../modules/audio/pro-audio.nix
    ../../modules/audio/plugin-dev.nix
    ../../modules/virtualization/libvirt-vfio.nix
    ../../modules/dev/cuda-ml.nix
    ../../modules/dev/languages.nix
    ../../modules/creative/render-gamedev.nix
  ];

  networking.hostName = "desktop";

  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/London"; # change to your timezone
  i18n.defaultLocale = "en_GB.UTF-8";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Ryzen 5800X — microcode + typical desktop power profile
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  powerManagement.cpuFreqGovernor = "schedutil";

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # AMD-V + IOMMU for VFIO (VFIO module adds more kernelParams)
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
  ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # No Bluetooth on this machine
  hardware.bluetooth.enable = false;
  services.blueman.enable = false;

  services.openssh.enable = true;
  services.printing.enable = false;

  # PipeWire tuned in modules/audio/pro-audio.nix

  # Base CLI tools on the system profile (Home Manager adds user copies too)
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    vim
    neovim
    firefox
    steam
    pciutils
    usbutils
    virt-manager
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.nix-ld.enable = true;

  programs.zsh.enable = true;

  users.users.sarah = {
    isNormalUser = true;
    description = "Sarah";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "libvirtd"
      "kvm"
      "plugdev"
      "input"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  system.stateVersion = "25.11";
}
