# Downstream host module: ACB issue service (SQLite + HTTP API).
#
# The system unit comes from the ACB flake's deploy/nix/issue-service.nix; that
# module is disabled by default and hardcodes /var/lib/acb-issue/issues.db.
# Here we enable it, pin it to a static account (the upstream unit uses
# DynamicUser, whose numeric uid is not stable across reboots and therefore
# cannot own a preservation mount), and point the bridge-side tool provider at
# the loopback listener.
#
# The service itself never reads ACB_ISSUE_TOKEN: it validates bearer tokens
# stored (hashed) in SQLite. The provider acb-issue-tools is spawned by
# acb-bridge and inherits the bridge environment, so the token belongs in the
# existing agenix secret config.age.secrets."acb.env", not in this unit.
{
  lib,
  pkgs,
  acb,
  ...
}:
{
  imports = [ (acb.outPath + "/deploy/nix/issue-service.nix") ];

  services.acb-issue-service = {
    enable = true;
    # acb-bridge builds the whole Cargo workspace, so its output also carries
    # bin/acb-issue-service and bin/acb-issue-tools.
    package = acb.packages.${pkgs.system}.acb-bridge;
    listen = "127.0.0.1:7800";
    adminPrincipal = "admin";
  };

  # A stable account owns the preserved SQLite database.
  systemd.services.acb-issue-service.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "acb-issue";
    Group = "acb-issue";
  };

  # The process-tools provider defaults to this URL; make the coupling explicit
  # so a later listen change cannot silently break the bridge.
  systemd.user.services.acb-bridge.serviceConfig.Environment = [
    "ACB_ISSUE_URL=http://127.0.0.1:7800"
  ];
}
