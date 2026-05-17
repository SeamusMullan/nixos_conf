# Messaging: Discord (Vesktop), Matrix, Signal, LocalSend, and common chat apps.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.communications;

  matrixPackages =
    {
      element = [ pkgs.element-desktop ];
      fractal = [ pkgs.fractal ];
      nheko = [ pkgs.nheko ];
    }
    .${cfg.matrixClient}
    or [ ];

  discordPackages =
    if cfg.discordClient == "vesktop" then
      [ pkgs.vesktop ]
    else
      [ ];
in
{
  options.custom.communications = {
    enable = lib.mkEnableOption "messaging and chat applications";

    discordClient = lib.mkOption {
      type = lib.types.enum [
        "vesktop"
        "none"
      ];
      default = "vesktop";
      description = "Discord client; Vesktop includes Vencord.";
    };

    matrixClient = lib.mkOption {
      type = lib.types.enum [
        "element"
        "fractal"
        "nheko"
        "none"
      ];
      default = "element";
      description = "Matrix client (Element is the default Element Web/desktop build).";
    };

    enableSignal = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    enableLocalSend = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    enableTelegram = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Telegram Desktop.";
    };

    enableSlack = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Slack desktop client.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    programs.signal-desktop = lib.mkIf cfg.enableSignal {
      enable = true;
    };

    environment.systemPackages =
      discordPackages
      ++ matrixPackages
      ++ lib.optionals cfg.enableLocalSend [ pkgs.localsend ]
      ++ lib.optionals cfg.enableTelegram [ pkgs.telegram-desktop ]
      ++ lib.optionals cfg.enableSlack [ pkgs.slack ];
  };

  custom.communications.enable = lib.mkDefault true;
}
