{
  myvars,
  config,
  lib,
  ...
}:
# Pin the GIDs/UIDs so they are not reassigned if the group is missing.
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
  };
}
