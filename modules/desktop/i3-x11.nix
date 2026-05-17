{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.xserver = {
    enable = true;
    layout = "gb";
    xkbVariant = "";
    desktopManager = { };
    displayManager.defaultSession = "i3";
    displayManager.lightdm = {
      enable = true;
      greeters.gtk.enable = true;
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        i3status
        i3lock
        picom
        rofi
        feh
        arandr
        xss-lock
        nitrogen
      ];
    };

  };

  services.libinput.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "0";
    GDK_BACKEND = "x11";
    QT_QPA_PLATFORM = "xcb";
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override [ "FiraCode" "JetBrainsMono" ])
    noto-fonts
    noto-fonts-emoji
    liberation_ttf
  ];
}
