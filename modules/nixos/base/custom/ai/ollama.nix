# Local Ollama inference server, consolidated from the three per-host
# ai/ollama.nix copies (they differed only in enable state and cuda package).
{
  config,
  lib,
  pkgs,
  myvars,
  ...
}:
let
  cfg = config.modules.ollama;
  # Single-sourced with the homepage overview page: enable/host/port/cuda all
  # come from the service row in vars/networking-downstream.nix; hosts select
  # their row with `modules.ollama.hostKey`. Hosts without a row (and hosts
  # that never set hostKey) simply do not run Ollama.
  row =
    if cfg.hostKey != null && builtins.hasAttr cfg.hostKey myvars.networking.services.ollama.hosts then
      myvars.networking.services.ollama.hosts.${cfg.hostKey}
    else
      null;
in
{
  options.modules.ollama = {
    # Which registry row (vars.networking.services.ollama.hosts.<key>) this
    # host runs; null keeps the server off.
    hostKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Key of this host's row in the ollama service registry.";
    };
  };

  config = lib.mkIf (row != null && row.enable) {
    services.ollama = {
      enable = true;
      package = if (row.cuda or false) then pkgs.ollama-cuda else pkgs.ollama;
      user = "ollama";
      group = "ollama";
      host = row.host;
      port = row.port;
      environmentVariables = {
        OLLAMA_ORIGINS = "*";
      };
      home = "/var/lib/ollama";
      # models = "${home}/models";
    };
  };
}
