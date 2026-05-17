# Audio plugin development: LV2 / CLAP toolchain, Reaper, Wine for future FL/Ableton.
# Wine prefixes and Windows DAW installers are NOT configured here.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.pluginDev;
  winePkg = pkgs.wineWowPackages.stableFull;
in
{
  options.custom.pluginDev = {
    enable = lib.mkEnableOption "audio plugin development and DAW tooling";

    enableReaper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "REAPER DAW (unfree).";
    };

    enableWine = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Wine + Winetricks + WineASIO for future FL Studio / Ableton (no prefix/DAW setup yet).
      '';
    };

    enableYabridge = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        yabridge for Windows VSTs inside native Linux DAWs (separate from running FL/Ableton in Wine).
      '';
    };

    enableVst3Sdk = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Steinberg VST3 SDK (unfree).";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    programs.wine = lib.mkIf cfg.enableWine {
      enable = true;
      package = winePkg;
    };

    environment.systemPackages =
      with pkgs;
      [
        # LV2 / CLAP
        lv2
        lilv
        suil
        serd
        sord
        sratom
        clap
        clap-validator
        pluginval

        # Plugin hosts (testing)
        carla
        jalv

        # DSP / frameworks
        faust
        juce

        # Libraries
        fftw
        libsndfile
        libsamplerate
        rubberband
        libjack2
        portaudio

        # Build
        pkg-config
        cmake
        ninja
        gcc
        clang
        gdb
      ]
      ++ lib.optionals cfg.enableReaper [ reaper ]
      ++ lib.optionals cfg.enableWine [
        winetricks
        wineasio
      ]
      ++ lib.optionals cfg.enableYabridge [
        yabridge
        yabridgectl
      ]
      ++ lib.optionals cfg.enableVst3Sdk [ vst3sdk ];

    environment.etc."plugin-dev/README".text = ''
      Plugin development (LV2 / CLAP)
      ===============================
      pkg-config --libs lilv-0 lv2
      jalv.gtk3 ./YourPlugin.lv2
      clap-validator validate ./YourPlugin.clap
      pluginval --strictness-level 5 ./YourPlugin.so
      carla  # patchbay / plugin rack

      REAPER: reaper  → Preferences → Plug-ins (scan when builds exist)

      Wine DAWs (FL Studio / Ableton) — not configured yet
      ======================================================
      Suggested prefixes:
        ~/.wine-daws/flstudio/
        ~/.wine-daws/ableton/

      When ready:
        WINEPREFIX=~/.wine-daws/flstudio wineboot -i
        winetricks wineasio
        wine /path/to/installer.exe

      PipeWire+JACK from pro-audio.nix; wire Scarlett in qpwgraph/helvum.

      yabridge (Windows VSTs in native REAPER, not full FL/Ableton):
        yabridgectl add <path>
        yabridgectl sync
    '';
  };

  custom.pluginDev.enable = lib.mkDefault true;
}
