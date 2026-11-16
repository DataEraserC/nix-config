{
  myvars,
  config,
  lib,
  ...
}:
# Declares the service accounts and groups on every NixOS host: sets
# isSystemUser and the primary group so the names exist even when their service
# is disabled. This file does NOT pin numeric uid/gid; those are pinned in
# hosts/service-user-ids.nix, which only applies to the hosts importing it.
{
  users.groups = {
    # sunshine
    # To persist the sunshine identity across login and greeter sessions,
    # create a dedicated group for sharing the data directory.
    sunshine = { };
    # gnome-remote-desktop
    gnome-remote-desktop = { };
    # cliproxyapi
    cliproxyapi = { };
    # m365-copilot2api
    m365-copilot2api = { };
    # opencode2api
    opencode2api = { };
    # meoo2api
    meoo2api = { };
    # ollama
    ollama = { };
    # new-api
    new-api = { };
    # new-api
    alist = { };
  };
  users.users = {
    gnome-remote-desktop = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "gnome-remote-desktop";
    };
    cliproxyapi = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "cliproxyapi";
    };
    m365-copilot2api = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "m365-copilot2api";
    };
    opencode2api = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "opencode2api";
    };
    meoo2api = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "meoo2api";
    };
    ollama = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "ollama";
    };
    new-api = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "new-api";
    };
    alist = {
      isNormalUser = lib.mkDefault false;
      isSystemUser = lib.mkDefault true;
      group = "alist";
    };
  };
}
