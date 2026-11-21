# ===============================================================================
#
# Agent2API - multi-provider subscription accounts to OpenAI/Anthropic
# compatible API gateway, with a web management panel.
#
# The gateway and its provider plugins are maintained outside this repository:
# the `agent2api-nix` flake packages the plugins (autoPatchelf'd so the native
# ELF packs run on NixOS) and provides `services.agent2api`, including the
# plugin sync and both systemd units. This wrapper only pins the headless
# server package (`agent2api-server`, from the DataEraserC NUR) and maps the
# fork's host options onto that module.
#
# Binds to 0.0.0.0:1108 and serves both the OpenAI-compatible API (/v1/*) and
# the panel on that single port. The host firewall only trusts the VPN overlays
# (tailscale/zerotier/easytier), so the panel is not exposed to the LAN; the
# API and panel are plain HTTP, so keep a TLS reverse proxy in front when
# reaching them from an untrusted network.
#
# The adminPasswordFile secret seeds the panel administrator on first start and
# again whenever its content changes (the password is stored as a bcrypt hash,
# so rotating the file takes effect on the next restart). The panel captcha is
# off: the panel is reachable over the VPN only and the password is a random
# agenix value.
#
# The gateway fails closed: /v1/* answers 401 until an API key is created in the
# panel, which is the intended posture for a host that stores provider
# credentials. State (SQLite database with accounts, API keys, request logs, and
# the credential encryption key) lives in /var/lib/agent2api, preserved by the
# host's impermanence setup.
#
# `plugins` is empty by default. Add any of
# `inputs.agent2api-nix.packages.${system}.*` to install provider packs:
#   agent2api-providers       - 提供商增强 (native)
#   agent2api-web-providers   - 网页提供商 (native)
#   agent2api-wasm-trae       - Trae (wasm)
#   agent2api-wasm-zcode      - ZCode 国内版 (wasm)
# `mode = "managed"` reconciles the set (and the per-provider switches) on every
# start; `mode = "mutable"` seeds once and then leaves the plugin directory
# alone.
#
# Check Service Status
#   systemctl status agent2api
# Check logs
#   journalctl -u agent2api --since "2 minutes ago"
# Read the admin password
#   sudo cat /run/agenix/agent2api-admin-password
{
  config,
  lib,
  pkgs,
  inputs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.agent2api;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ inputs.agent2api-nix.nixosModules.default ];

  options.modules.agent2api = {
    enable = lib.mkEnableOption "Agent2API gateway";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port Agent2API listens on for both the API and the panel; the host that uses this module must set it (port registry myvars.networking.services.agent2api.hosts.<machine>.port).";
    };
    panelPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Serve the management panel on its own port instead of `port`, so only the API port has to be reachable; must differ from `port`.";
    };
    mode = lib.mkOption {
      type = lib.types.enum [
        "managed"
        "mutable"
      ];
      default = "managed";
      description = "managed reconciles the plugin set and provider switches on every start; mutable seeds once and then leaves the plugin directory alone.";
    };
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Agent2API provider plugin packs to install; empty by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.agent2api = {
      enable = true;
      package = nur-DataEraserC.packages.${system}.agent2api-server;
      inherit (cfg)
        port
        panelPort
        mode
        plugins
        ;
      host = "0.0.0.0";
      adminUser = "admin";
      adminPasswordFile = "/run/agenix/agent2api-admin-password";
      captcha = false;
      openFirewall = false;
    };
  };
}
