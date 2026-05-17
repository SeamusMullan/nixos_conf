# Low-latency PipeWire stack for Focusrite Scarlett (and other USB/pro interfaces).
# Scarlett class-compliant modes work out of the box; for full mixer control on some
# models, consider `focusrite-control` from nixpkgs or alsa-scarlett-gui if you use ALSA mixers.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.proAudio;
in
{
  options.custom.proAudio = {
    enable = lib.mkEnableOption "professional low-latency PipeWire audio";
    sampleRate = lib.mkOption {
      type = lib.types.int;
      default = 48000;
      description = "Default sample rate (Hz). Scarlett often runs 48k or 96k.";
    };
    quantum = lib.mkOption {
      type = lib.types.int;
      default = 256;
      description = "PipeWire buffer size in frames; 128/256 for tracking, 512+ for mixing.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;

      extraConfig.pipewire."99-pro-audio" = {
        "context.properties" = {
          "default.clock.rate" = cfg.sampleRate;
          "default.clock.quantum" = cfg.quantum;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 2048;
        };
        "context.modules" = [
          {
            name = "libpipewire-module-rt";
            args = {
              "nice.level" = -11;
              "rt.prio" = 88;
              "rt.time.soft" = 2000000;
              "rt.time.hard" = 2000000;
            };
            flags = [ "ifexists" ];
          }
        ];
      };

      extraConfig.pipewire-pulse."99-pro-audio" = {
        "pulse.properties" = {
          "pulse.min.req" = "256/48000";
          "pulse.default.req" = "256/48000";
          "pulse.default.format" = "F32LE";
          "pulse.default.position" = "[ FL FR ]";
        };
      };
    };

    # Realtime scheduling for audio group
    security.pam.loginLimits = [
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "95";
      }
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "nice";
        type = "-";
        value = "-19";
      }
    ];

    environment.systemPackages = with pkgs; [
      pavucontrol
      helvum
      qpwgraph
      pipewire
    ];

    # Stable USB for Scarlett — avoid autosuspend dropping the interface
    services.udev.extraRules = ''
      # Focusrite Scarlett USB — keep awake
      SUBSYSTEM=="usb", ATTR{idVendor}=="1235", ATTR{power/autosuspend}="-1"
    '';

    services.udev.packages = [ pkgs.alsa-utils ];
  };

  custom.proAudio.enable = lib.mkDefault true;
}
