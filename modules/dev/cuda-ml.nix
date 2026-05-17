# CUDA toolkit, containers, and build tooling for ML on the host NVIDIA GPU.
# PyTorch / Jupyter / Hugging Face stack: home/sarah/ml-python.nix

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.cudaMl;

  nvidiaDriver =
    if config.hardware.nvidia ? package && config.hardware.nvidia.package != null then
      config.hardware.nvidia.package
    else
      config.boot.kernelPackages.nvidiaPackages.production;

  cuda = nvidiaDriver.cudaPackages;
in
{
  options.custom.cudaMl = {
    enable = lib.mkEnableOption "CUDA libraries and ML infrastructure on the host GPU";

    enableDocker = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Docker + NVIDIA Container Toolkit (use --device nvidia.com/gpu=all on 25.05+).";
    };

    enableNsight = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Nsight Systems / Compute (large downloads; enable when profiling).";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config = {
      allowUnfree = true;
      cudaSupport = true;
    };

    hardware.nvidia.persistenced.enable = lib.mkDefault true;

    environment.systemPackages =
      with pkgs;
      [
        cuda.cudatoolkit
        cuda.cudnn
        cuda.nccl
        nvtop
        nvidia-utils
        cmake
        ninja
        gnumake
        pkg-config
        gcc
        git-lfs
        uv
        hdf5
        rustc
        cargo
        clang
      ]
      ++ lib.optionals cfg.enableNsight (
        lib.filter lib.isDerivation [
          cuda.nsight-compute
          cuda.nsight-systems
        ]
      );

    environment.sessionVariables = {
      CUDA_HOME = "${cuda.cudatoolkit}";
      CUDA_PATH = "${cuda.cudatoolkit}";
    };

    virtualisation.docker.enable = lib.mkIf cfg.enableDocker true;
    hardware.nvidia-container-toolkit.enable = lib.mkIf cfg.enableDocker true;

    users.users.sarah.extraGroups = lib.optionals cfg.enableDocker [ "docker" ];
  };

  custom.cudaMl.enable = lib.mkDefault true;
}
