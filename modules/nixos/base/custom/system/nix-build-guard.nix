{
  config,
  lib,
  myvars,
  ...
}:
let
  cfg = config.modules.nix-build-guard;
in
{
  options.modules.nix-build-guard = {
    enable = lib.mkEnableOption "cgroup memory guardrails for Nix builds";

    daemonMemoryHigh = lib.mkOption {
      type = lib.types.str;
      default = myvars.nixBuildGuard.daemonMemoryHigh;
      description = "systemd MemoryHigh for nix-daemon.service (throttle before the hard cap).";
    };

    daemonMemoryMax = lib.mkOption {
      type = lib.types.str;
      default = myvars.nixBuildGuard.daemonMemoryMax;
      description = "systemd MemoryMax for nix-daemon.service; the hard limit for all builders.";
    };

    maxJobs = lib.mkOption {
      type = lib.types.int;
      default = myvars.nixBuildGuard.maxJobs;
      description = "nix.settings.max-jobs; conservative default to keep concurrent builders inside the memory budget.";
    };

    cores = lib.mkOption {
      type = lib.types.int;
      default = myvars.nixBuildGuard.cores;
      description = "nix.settings.cores; limits CPU parallelism per builder instead of using all cores.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      max-jobs = cfg.maxJobs;
      cores = cfg.cores;
    };

    systemd.services.nix-daemon.serviceConfig = {
      MemoryHigh = cfg.daemonMemoryHigh;
      MemoryMax = cfg.daemonMemoryMax;
    };
  };
}
