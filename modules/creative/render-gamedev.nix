# 3D rendering, DCC, and game development tooling (Blender, Godot, etc.).
# Uses host NVIDIA + Vulkan; pairs with Steam/gamemode for playtesting.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.renderGamedev;

  blenderPkg =
    if cfg.blenderPackage != null then
      cfg.blenderPackage
    else
      pkgs.blender;
in
{
  options.custom.renderGamedev = {
    enable = lib.mkEnableOption "3D rendering and game development applications";

    blenderPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Blender package override; null = nixpkgs blender.";
    };

    enableUnityHub = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Unity Hub (unfree; large). Enable in local.nix if needed.";
    };

    enableGameMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Feral GameMode for smoother playtests (works with Steam).";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };

    programs.gamemode = lib.mkIf cfg.enableGameMode {
      enable = true;
    };

    # Prefer NVIDIA for GLX/Vulkan DCC viewports (harmless on single-GPU desktop)
    environment.sessionVariables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };

    environment.systemPackages =
      with pkgs;
      [
        # --- 3D / rendering ---
        blenderPkg
        gimp
        krita
        inkscape
        ffmpeg
        mediainfo
        mpv
        openimageio
        meshlab
        freecad

        # --- Game engines & editors ---
        godot_4
        godot_4-export-templates
        tiled
        ldtk

        # --- Graphics APIs & debugging ---
        vulkan-tools
        vulkan-validation-layers
        glslang
        shaderc
        renderdoc
        apitrace

        # --- Playtesting / perf ---
        mangohud
        goverlay
        greenwithenvy
        lutris

        # --- Audio for games (design / middleware prototyping) ---
        audacity

        # --- General gamedev utilities ---
        imagemagick
        pngcrush
        optipng
        zip
        unzip
      ]
      ++ lib.optionals cfg.enableUnityHub [ unityhub ];
  };

  custom.renderGamedev.enable = lib.mkDefault true;
}
