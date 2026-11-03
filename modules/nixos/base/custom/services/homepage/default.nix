# ===============================================================================
#
# Service overview page - a static page generated from the port registry.
#
# Source of truth: myvars.networking.services. Every service that carries a
# `catalog` block and has an enabled row for one of the hosts in
# myvars.networking.homepage.hosts becomes one card. Ports, bind addresses and
# enable state are read from the same row the service's own module consumes, so
# the page never restates them. A new service is one registry edit; a new host
# is one row in `homepage.hosts` plus the four options below in the host file.
#
# The page is plain HTML/CSS/JS served by Caddy on `port`. The service data and
# both locale catalogs are embedded in the document, so no JSON fetch and no
# client-side framework are involved. Runtime host detection compares the page
# host with the registered overlay and MagicDNS addresses and falls back to the
# host key this page was generated for. LAN addresses are deliberately not read:
# cross-host access is defined by the overlay registrations in
# myvars.networking.devices only.
#
# Check service status
#   systemctl status caddy
# Check logs
#   journalctl -u caddy
# ===============================================================================
{
  config,
  lib,
  pkgs,
  myvars,
  ...
}:
let
  cfg = config.modules.homepage;
  network = myvars.networking;

  hostMeta =
    if builtins.hasAttr cfg.hostKey network.homepage.hosts then
      network.homepage.hosts.${cfg.hostKey}
    else
      throw "modules.homepage.hostKey: \"${cfg.hostKey}\" is not declared in myvars.networking.homepage.hosts";

  # Only services opted into the page; the catalog block is the opt-in marker.
  catalogServices = lib.filterAttrs (_: service: service ? catalog) network.services;

  # Resolve the listed endpoint from the host row. `portKey` is a dotted path so
  # a service can point at a secondary listener (adminPort, ports.console, ...).
  portOf =
    name: hostKey: row:
    let
      catalog = catalogServices.${name}.catalog;
      portKey = catalog.portKey or "port";
      value = lib.attrByPath (lib.splitString "." portKey) null row;
    in
    if value == null then
      throw "modules.homepage: service \"${name}\" has no port at \"${portKey}\" for host \"${hostKey}\""
    else if !lib.isInt value then
      throw "modules.homepage: service \"${name}\" port \"${portKey}\" for host \"${hostKey}\" is not an integer"
    else
      value;

  # Enabled (service x host) rows in port order, matching the registry's
  # ordering convention. Rows without `enable` (ssh) default to enabled, but ssh
  # carries no catalog block and is therefore not listed.
  servicesOf =
    hostKey:
    lib.sort (a: b: a.port < b.port) (
      lib.concatMap (
        name:
        let
          service = catalogServices.${name};
          row = service.hosts.${hostKey} or null;
        in
        if row == null || !(row.enable or true) then
          [ ]
        else
          let
            catalog = service.catalog;
          in
          [
            {
              inherit name;
              label = catalog.label or name;
              protocol = catalog.protocol or "http";
              port = portOf name hostKey row;
              path = catalog.path or "/";
              tags = catalog.tags or [ ];
              note = catalog.note or null;
              bind = lib.attrByPath (lib.splitString "." (catalog.bindKey or "host")) null row;
            }
          ]
      ) (lib.attrNames catalogServices)
    );

  hostData = lib.mapAttrs (
    hostKey: meta:
    let
      device = meta.device or null;
      overlays =
        if device == null then
          { }
        else
          lib.mapAttrs (_: overlay: { inherit (overlay) ip prefixLength; }) network.devices.${device}.addrs;
    in
    {
      inherit hostKey;
      inherit (meta) kind magicDns;
      inherit overlays;
      # No overlay registration means no cross-host path: the page marks the
      # host as unreachable from other machines and never falls back to LAN.
      crossHostReachable = overlays != { };
      services = servicesOf hostKey;
    }
  ) network.homepage.hosts;

  locales = lib.genAttrs cfg.languages (
    lang:
    let
      file = ./locales + "/${lang}.json";
    in
    if builtins.pathExists file then
      builtins.fromJSON (builtins.readFile file)
    else
      throw "modules.homepage: no locale catalog at ${toString file} for language \"${lang}\""
  );

  pageData = {
    servedHost = cfg.hostKey;
    defaultLanguage = cfg.defaultLanguage;
    languages = cfg.languages;
    hosts = hostData;
  };

  # The skeleton carries no user-facing text: every label is created by app.js
  # from the locale catalogs below.
  indexHtml = pkgs.writeText "homepage-index.html" ''
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title></title>
        <link rel="stylesheet" href="style.css" />
      </head>
      <body>
        <main id="app"></main>
        <script id="homepage-data" type="application/json">${builtins.toJSON pageData}</script>
        <script id="homepage-i18n" type="application/json">${builtins.toJSON locales}</script>
        <script src="app.js"></script>
      </body>
    </html>
  '';

  site = pkgs.runCommand "homepage-site" { } ''
    mkdir -p "$out"
    cp ${./style.css} "$out/style.css"
    cp ${./app.js} "$out/app.js"
    cp ${indexHtml} "$out/index.html"
  '';

  # A wildcard bind must stay hostless (":8090"): "0.0.0.0:8090" installs a
  # literal Host matcher that no request satisfies.
  siteAddr =
    if cfg.host == "0.0.0.0" || cfg.host == "::" then
      ":${toString cfg.port}"
    else
      "${cfg.host}:${toString cfg.port}";
in
{
  options.modules.homepage = {
    enable = lib.mkEnableOption "static service overview page";

    hostKey = lib.mkOption {
      type = lib.types.str;
      description = ''
        Registry key of this machine - the key used by
        myvars.networking.services.*.hosts and myvars.networking.homepage.hosts.
        It is not always config.networking.hostName: wsl-work runs with
        hostName "work".
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = ''
        TCP port Caddy serves the page on; the host that uses this module must
        set it (port registry myvars.networking.services.homepage.hosts.<machine>.port).
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Bind address of the Caddy site, taken from the registry row's `host`.";
    };

    defaultLanguage = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Locale used when neither the URL nor local storage selects one; must be listed in `languages`.";
    };

    languages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "en"
        "zh"
      ];
      description = "Locale catalogs under ./locales; each value needs a matching <lang>.json file.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.languages != [ ];
        message = "modules.homepage.languages must contain at least one locale";
      }
      {
        assertion = lib.elem cfg.defaultLanguage cfg.languages;
        message = "modules.homepage.defaultLanguage \"${cfg.defaultLanguage}\" is not listed in modules.homepage.languages";
      }
      {
        assertion = builtins.hasAttr cfg.hostKey network.homepage.hosts;
        message = "modules.homepage.hostKey \"${cfg.hostKey}\" is not declared in myvars.networking.homepage.hosts";
      }
    ];

    # A buildable output for the page alone, so validation needs no full system
    # closure: nix build .#nixosConfigurations.<host>.config.system.build.homepageSite
    system.build.homepageSite = site;

    services.caddy = {
      enable = true;
      enableReload = true;
      # Port-only vhosts stay on plain HTTP; they never enter Caddy's ACME
      # machinery, so no auto_https override is needed here.
      virtualHosts.${siteAddr}.extraConfig = ''
        encode gzip
        root * ${site}
        file_server
      '';
    };
  };
}
