# User Python environment for CUDA ML (PyTorch, notebooks, Hugging Face).
# Packages not in nixpkgs (e.g. bitsandbytes): use `uv venv` in a project dir.
# Test after rebuild: ml-check

{
  pkgs,
  lib,
  ...
}:

let
  pythonMl = pkgs.python3.withPackages (
    ps: with ps;
    [
      # PyTorch (CUDA when nixpkgs.config.cudaSupport = true)
      torch
      torchvision
      torchaudio

      # Scientific stack
      numpy
      scipy
      pandas
      scikit-learn
      matplotlib
      seaborn

      # Notebooks
      jupyter
      jupyterlab
      ipython
      ipykernel
      notebook

      # Hugging Face
      transformers
      accelerate
      datasets
      tokenizers
      safetensors
      huggingface-hub
      einops
      sentencepiece
      peft

      # Experiment tracking & viz
      tensorboard
      tqdm
      wandb

      # Vision & data
      pillow
      opencv4
      pyyaml
      h5py

      # ONNX
      onnx

      # Utilities
      aiohttp
      httpx
      rich
      pydantic
      pytest
      ruff
      black
      mypy
      pip
      wheel
      setuptools
    ]
  );
in
{
  home.packages = [
    pythonMl
    pkgs.uv
    pkgs.poetry
    pkgs.pre-commit
  ];

  home.sessionPath = [ "${pythonMl}/bin" ];

  home.shellAliases = {
    ml-check = "nvidia-smi; python -c \"import torch; print('torch', torch.__version__); print('cuda', torch.cuda.is_available()); print('device', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'n/a')\"";
    jlab = ''jupyter lab --notebook-dir=$HOME'';
  };

  programs.zsh.initExtra = lib.mkAfter ''
    # CUDA paths from modules/dev/cuda-ml.nix
    if [ -n "''${CUDA_HOME:-}" ]; then
      export PATH="''${CUDA_HOME}/bin:''${PATH}"
    fi
  '';
}
