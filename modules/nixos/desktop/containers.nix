{
  config,
  lib,
  ...
}:
{
  ###################################################################################
  #
  #  Containers - Podman
  #
  ###################################################################################

  virtualisation = {
    # Do not use "--restart=always" to create container, or shutdown/reboot will be slow
    # https://github.com/containers/podman/issues/15284
    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
      # No `autoPrune`: it prunes the *rootful* store and depends on the rootful
      # API service, neither of which a rootless-only desktop uses. Prune the
      # rootless store with the user timer below instead.
    };

    # Bound container log growth. Podman uses journald when the journal is
    # writable, but rootless sessions can fall back to a file driver
    # (k8s-file / json-file), which otherwise grows without limit.
    containers.containersConf.settings.containers.log_size_max = 10 * 1024 * 1024;

    # Containers registries configuration (shared by Docker and Podman)
    # https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md
    containers = {
      registries = {
        # Unqualified image names (e.g. "nginx") will be searched in these registries in order
        search = [
          "docker.io"
          "quay.io"
          "ghcr.io"
          "registry.k8s.io"
          "mcr.microsoft.com"
          "gcr.io"
        ];
        # Insecure registries (HTTP instead of HTTPS) - add as needed
        insecure = [ ];
        # Blocked registries - block any known malicious or unused registries
        block = [ ];
      };
    };

    # Usage: https://wiki.nixos.org/wiki/Waydroid
    waydroid.enable = true;
  };

  # Desktop hosts use rootless podman only: the user is not in the `podman`
  # group, so the rootful system socket is unreachable and nothing here uses the
  # Docker/podman API. Disable it anyway so it cannot be reached by accident.
  # The per-user rootless socket (systemd.user.sockets.podman) is unaffected.
  systemd.sockets.podman.enable = false;

  # Prune the rootless store (the module's autoPrune only covered the rootful
  # one). Runs in the user's session, so it fires while the desktop is logged in.
  systemd.user.services.podman-prune = {
    description = "Prune rootless podman resources";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe config.virtualisation.podman.package} system prune -f --all";
    };
  };
  systemd.user.timers.podman-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}
