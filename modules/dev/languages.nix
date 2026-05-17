# Developer language toolchains: C/C++, Python, JS/TS (bun), Java, Rust, Go, Lua, ASM.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.languages;

  jdk =
    {
      "17" = pkgs.jdk17;
      "21" = pkgs.jdk21;
    }
    .${cfg.javaVersion}
    or pkgs.jdk21;

  pythonDev = pkgs.python3.withPackages (
    ps: with ps;
    [
      pip
      virtualenv
      ipython
      pytest
      black
      ruff
      mypy
      pylint
      autopep8
    ]
  );
in
{
  options.custom.languages = {
    enable = lib.mkEnableOption "developer language toolchains";

    javaVersion = lib.mkOption {
      type = lib.types.enum [
        "17"
        "21"
      ];
      default = "21";
      description = "Default JDK for coursework and tooling.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        # --- C / C++ ---
        gcc
        clang
        lldb
        gdb
        cmake
        meson
        ninja
        gnumake
        pkg-config
        mold
        lld
        bear
        ccache
        clang-tools
        cppcheck
        valgrind
        include-what-you-use

        # --- ASM / low-level ---
        nasm
        yasm
        binutils
        hexedit
        radare2

        # --- Python (general dev; ML stack is in home/sarah/ml-python.nix) ---
        pythonDev
        uv
        poetry

        # --- JavaScript / TypeScript ---
        bun
        nodejs_22
        nodePackages.prettier
        nodePackages.typescript
        nodePackages.typescript-language-server
        nodePackages.eslint

        # --- Java ---
        jdk
        maven
        gradle
        kotlin

        # --- Rust ---
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer

        # --- Go ---
        go
        gopls
        delve

        # --- Lua ---
        lua54
        luajit
        luarocks

        # --- General dev utilities ---
        git
        git-lfs
        gh
        pre-commit
        shellcheck
        shfmt
        nixfmt-rfc-style
        gnum4
        autoconf
        automake
        libtool
      ];
  };

  custom.languages.enable = lib.mkDefault true;
}
