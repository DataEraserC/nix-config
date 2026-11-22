# Local Ollama inference server, consolidated from the three per-host
# ai/ollama.nix copies (they differed only in enable state and cuda package).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.ollama;
in
{
  options.modules.ollama = {
    enable = lib.mkEnableOption "the Ollama inference server";

    cuda = lib.mkEnableOption "the CUDA-enabled ollama build (NVIDIA hosts)";
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = if cfg.cuda then pkgs.ollama-cuda else pkgs.ollama;
      user = "ollama";
      group = "ollama";
      host = "0.0.0.0";
      port = 11434;
      environmentVariables = {
        OLLAMA_ORIGINS = "*";
      };
      home = "/var/lib/ollama";
      # models = "${home}/models";
    };
  };
}
