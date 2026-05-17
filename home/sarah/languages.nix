# User-level dev ergonomics: bun, direnv, quick aliases.

{
  pkgs,
  ...
}:

{
  programs.bun.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    yq-go
    hyperfine
    tokei
  ];

  home.sessionVariables = {
    npm_config_prefix = "$HOME/.npm-global";
  };

  home.shellAliases = {
    py = "python3";
    cb = "cargo build";
    ct = "cargo test";
    cr = "cargo run";
    gob = "go build";
    got = "go test";
    jv = "java --version";
    bnr = "bun run";
    bni = "bun install";
  };
}
