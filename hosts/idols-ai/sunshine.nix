{
  config,
  lib,
  myvars,
  ...
}:
let
  # gdm-greeter users are declared by the nixpkgs gdm module as a fixed pool:
  #   lib.genAttrs' [ null 1 2 3 4 ] (...)
  # producing `gdm-greeter`, `gdm-greeter-2`, ..., `gdm-greeter-5`.
  # Keep this list in sync with that module if the pool changes.
  greeters = [
    "gdm-greeter"
  ]
  ++ (map (i: "gdm-greeter-${toString i}") [
    2
    3
    4
    5
  ]);
  sunshineUsers = [
    myvars.username
  ]
  ++ (if config.services.displayManager.gdm.enable then greeters else [ ]);
in
{
  config = lib.mkIf (config.services.sunshine.enable) {
    # The GDM greeter is itself a full graphical session running as one of the
    # `gdm-greeter` users, so the globally-enabled sunshine user service also
    # starts there. Its XDG dirs point at /var/lib/gdm/seat0/{config,state},
    # which GDM recreates on every greeter start, so each time it generated a
    # fresh self-signed certificate -> Moonlight required a new pairing every
    # boot. Give both the login session and the greeter the same persistent
    # identity by pointing them at one shared, group-writable data directory.
    #
    # Note: on hosts with an ephemeral root, persisting /var/lib/sunshine
    # across reboots is declared in the host's preservation module, NOT here.

    # dedicated group whose sole purpose is sharing sunshine data
    users.groups.sunshine = { };

    users.users = lib.genAttrs (sunshineUsers) (name: {
      extraGroups = [ "sunshine" ];
    });

    # Bootstrap the shared dirs. `d` creates them; `z` re-asserts
    # group/ownership/mode on every boot (setgid so anything created inside
    # inherits group `sunshine`).
    systemd.tmpfiles.rules = [
      # The preservation bind mount itself must be traversable by members of
      # the sunshine group. Fix the mount root before its child directories.
      "d /var/lib/sunshine 2770 root sunshine - -"
      "z /var/lib/sunshine 2770 root sunshine - -"
      "d /var/lib/sunshine/config 2770 root sunshine - -"
      "z /var/lib/sunshine/config 2770 root sunshine - -"
      "d /var/lib/sunshine/state 2770 root sunshine - -"
      "z /var/lib/sunshine/state 2770 root sunshine - -"
    ];

    # login + greeter sunshine instances share one identity directory
    systemd.user.services.sunshine.serviceConfig = {
      Environment = [
        "XDG_CONFIG_HOME=/var/lib/sunshine/config"
        "XDG_STATE_HOME=/var/lib/sunshine/state"
      ];
      # New files are group-writable so whichever instance (login or greeter,
      # both members of group `sunshine`) wrote a file, the other can update it.
      UMask = "0002";
    };
  };
}
