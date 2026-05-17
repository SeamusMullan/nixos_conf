{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./ml-python.nix
    ./languages.nix
  ];
  home.username = "sarah";
  home.homeDirectory = "/home/sarah";
  home.stateVersion = "25.11";

  # --- Shell ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };
    initContent = ''
      bindkey -v
      export EDITOR=nvim
      export VISUAL=nvim
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
      ];
      theme = "robbyrussell";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # --- Terminal ---
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    shellIntegration.enabled = "no-shell";
    settings = {
      scrollback_lines = 10000;
      copy_on_select = "yes";
      window_padding_width = 4;
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      cursor = "#f5e0dc";
    };
  };

  # --- Editor ---
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      set number relativenumber
      set expandtab shiftwidth=2 softtabstop=2
    '';
  };

  programs.git = {
    enable = true;
    userName = lib.mkDefault "Sarah";
    userEmail = lib.mkDefault "sarah@localhost";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # --- i3 ---
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "kitty";
      menu = "rofi -show drun";
      bars = [
        {
          status_command = "${pkgs.i3status}/bin/i3status -c ${config.xdg.configHome}/i3status/config";
          position = "bottom";
        }
      ];
    };
    extraConfig = ''
      # Autostart
      exec --no-startup-id picom -b
      exec --no-startup-id nitrogen --restore
      exec --no-startup-id xss-lock -- i3lock -c 000000

      # Workspaces
      set $ws1 "1"
      set $ws2 "2"
      set $ws3 "3"
      set $ws4 "4"
      set $ws5 "5"
      set $ws6 "6"
      set $ws7 "7"
      set $ws8 "8"
      set $ws9 "9"
      set $ws10 "10"

      bindsym $mod+1 workspace number $ws1
      bindsym $mod+2 workspace number $ws2
      bindsym $mod+3 workspace number $ws3
      bindsym $mod+4 workspace number $ws4
      bindsym $mod+5 workspace number $ws5
      bindsym $mod+6 workspace number $ws6
      bindsym $mod+7 workspace number $ws7
      bindsym $mod+8 workspace number $ws8
      bindsym $mod+9 workspace number $ws9
      bindsym $mod+0 workspace number $ws10

      bindsym $mod+Shift+1 move container to workspace number $ws1
      bindsym $mod+Shift+2 move container to workspace number $ws2
      bindsym $mod+Shift+3 move container to workspace number $ws3
      bindsym $mod+Shift+4 move container to workspace number $ws4
      bindsym $mod+Shift+5 move container to workspace number $ws5
      bindsym $mod+Shift+6 move container to workspace number $ws6
      bindsym $mod+Shift+7 move container to workspace number $ws7
      bindsym $mod+Shift+8 move container to workspace number $ws8
      bindsym $mod+Shift+9 move container to workspace number $ws9
      bindsym $mod+Shift+0 move container to workspace number $ws10

      # Rofi launcher
      bindsym $mod+d exec rofi -show drun

      # Screenshot
      bindsym $mod+Shift+s exec --no-startup-id maim -s | xclip -selection clipboard -t image/png

      # Audio (Pulse/PipeWire via pactl)
      bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
      bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
      bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
    '';
  };

  programs.i3status = {
    enable = true;
    settings = {
      general = {
        interval = 2;
        colors = true;
      };
      order = [
        "wireless _first_"
        "ethernet _first_"
        "battery all"
        "cpu_usage"
        "memory"
        "tztime local"
      ];
    };
  };

  # Desktop apps (Blender, Godot, etc.) are on the system profile via render-gamedev.nix
  home.packages = with pkgs; [
    git
    wget
    curl
    firefox
    steam
    rofi
    maim
    xclip
    playerctl
    htop
    ripgrep
    fd
    tree
    unzip
    jq
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  xdg.configFile."picom/picom.conf".text = ''
    backend = "glx";
    vsync = true;
    shadow = true;
    fading = true;
    fade-delta = 4;
    inactive-opacity = 0.95;
    corner-radius = 6;
  '';
}
