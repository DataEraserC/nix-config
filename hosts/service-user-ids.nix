# Shared downstream service-id table for the AI and WSL hosts.
#
# Linux stores the numeric owner on disk, not the account name. When NixOS
# reallocates a service UID/GID after the system user set changes, files under
# /var/lib keep the old number and can resolve to an unrelated account. Pinning
# every service id prevents that remap; a service that is currently disabled is
# declared here too so enabling it later cannot shift its number.
#
# Values are the current numeric ids on idols-ai, read from /etc/passwd and
# /var/lib/nixos/{uid,gid}-map:
#
#   getent passwd gnome-remote-desktop cliproxyapi m365-copilot2api \
#     opencode2api ollama new-api alist agent2api omniroute \
#     our-free-model-standalone mimocode2api cpolar
#   getent group sunshine
#
# They are used for the WSL hosts under the same-allocation assumption. Verify
# them there with getent before relying on the pins there; NixOS never changes
# an existing account's uid/gid, so a mismatch only means the pin is inactive
# (the account keeps its old number) rather than corrupting the data.
#
# Not in this table:
#   - astrbot: not a pined/NUR service user, currently disabled, and its
#     historical gid 958 now belongs to wpa_supplicant; pinning it would need a
#     fresh gid and a data migration, which is outside this id-only change.
#   - hadoop: local bigdata module, disabled, and its uid is in the normal-user
#     range.
#
# The ids are global across these hosts on purpose: one table, no per-host
# copies. If the WSL hosts turn out to have different historical allocations,
# split this file per host and document why; do not silently change the shared
# values.
{ lib, ... }:
let
  serviceUsers = {
    gnome-remote-desktop = {
      uid = 989;
      gid = 984;
    };
    cliproxyapi = {
      uid = 995;
      gid = 994;
    };
    m365-copilot2api = {
      uid = 988;
      gid = 982;
    };
    opencode2api = {
      uid = 980;
      gid = 974;
    };
    ollama = {
      uid = 982;
      gid = 976;
    };
    new-api = {
      uid = 986;
      gid = 980;
    };
    alist = {
      uid = 998;
      gid = 997;
    };
    agent2api = {
      uid = 999;
      gid = 998;
    };
    omniroute = {
      uid = 981;
      gid = 975;
    };
    our-free-model-standalone = {
      uid = 979;
      gid = 973;
    };
    mimocode2api = {
      uid = 987;
      gid = 981;
    };
    cpolar = {
      uid = 993;
      gid = 992;
    };
    # ACB issue service: a new account, so take a free id below the current
    # 970+ block. The id must be fixed because the preserved SQLite database
    # under /var/lib/acb-issue is owned by this account across reboots.
    acb-issue = {
      uid = 950;
      gid = 950;
    };
  };

  # Sunshine has no account: the desktop user services run as the logged-in
  # user and only share the `sunshine` group.
  extraGroups = {
    sunshine = 964;
  };
in
{
  users.users = lib.mapAttrs (name: entry: {
    uid = entry.uid;
    isSystemUser = true;
    group = name;
  }) serviceUsers;

  users.groups =
    lib.mapAttrs (name: entry: { gid = entry.gid; }) serviceUsers
    // lib.mapAttrs (_: gid: { inherit gid; }) extraGroups;
}
