# ===============================================================================
#
# Multi-instance - run a program that hardcodes its state under $HOME as many
# times as you like, each instance with its own state directory.
#
# A program's state paths are listed once, in `apps.<name>.paths`. Each instance
# gets a directory under `stateRoot`, bind-mounted over every one of those paths
# with bubblewrap, so no package is patched or wrapped. Each instance also gets
# a private /tmp, because a program that derives a lock name from a state path
# sees the same path in every instance. The instance store itself is replaced by
# a tmpfs inside the sandbox, so one instance never sees the others.
#
# The sandbox remaps paths; it is not a confinement boundary. $HOME stays
# writable at its real path, so absolute work-directory paths, git config and
# build caches behave exactly as before. Only the listed state paths are
# replaced.
#
# Programs are just names: `multi-instance` resolves them with `command -v`, so
# an entry also covers a binary the user installed themselves.
#
# Usage
#   multi-instance <app> <instance> [args...]
#
# An instance always starts empty: nothing is copied from the program's existing
# state under $HOME, so a plain run keeps its own login untouched.
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.multi-instance;

  appType = lib.types.submodule {
    options = {
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          State paths the program hardcodes under $HOME and cannot be told to
          move, e.g. ".config/Some App". One per element; each instance gets its
          own copy of every one of them.
        '';
      };

      userDataDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          One of `paths`: the program's user data directory, for programs whose
          single-instance lock is named after it. Chromium and Electron derive
          the lock socket from that path, which every instance sees unchanged, so
          a second instance hands its window to the first. Set this and the
          directory is mounted a second time under a per-instance path passed as
          `--user-data-dir`, so the lock name differs while the data does not.
        '';
      };

      persist = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
        description = ''
          Subset of `paths` to carry across a tmpfs root, in the shape
          `preservation.preserveAt.<store>.users.<user>.directories` accepts: a
          path, or an attrset with `directory` and `mode`. Empty means the paths
          are not preserved.
        '';
      };

      desktop = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              label = lib.mkOption {
                type = lib.types.str;
                description = "Name shown in the launcher and as the app's generic name.";
              };
              icon = lib.mkOption {
                type = lib.types.str;
                description = "Icon name, usually the one the package's own .desktop file uses.";
              };
              wmclass = lib.mkOption {
                type = lib.types.str;
                description = "Startup window class, so the window is recognised as this app.";
              };
            };
          }
        );
        default = null;
        description = ''
          Set to `{ label; icon; wmclass; }` to give every instance a launcher
          entry. Programs without it are CLI-only and get none.
        '';
      };
    };
  };

  # The spec is the only thing the launcher reads at runtime: one line per
  # program, then its state paths, then an @-prefixed user data directory when it
  # has one. Keeping it a file, not shell arguments, means a path with a space
  # (`Trae CN`) never goes through desktop-entry quoting.
  spec = pkgs.writeText "multi-instance.spec" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: app:
        lib.concatStringsSep "|" (
          [ name ] ++ app.paths ++ lib.optional (app.userDataDir != null) "@${app.userDataDir}"
        )
      ) cfg.apps
    )
    + "\n"
  );

  # The only parameters nix passes to the script: the spec it reads and the store
  # its instances live in. bubblewrap and coreutils are the only tools it runs.
  multi-instance = pkgs.writeShellApplication {
    name = "multi-instance";
    runtimeInputs = [
      pkgs.bubblewrap
      pkgs.coreutils
    ];
    text = ''
      export MULTI_INSTANCE_SPEC=${spec}
      export MULTI_INSTANCE_ROOT="$HOME/${cfg.stateRoot}"
    ''
    + builtins.readFile ./multi-instance.sh;
  };

  # A number means that many instances, named "1".."N"; a list names them
  # explicitly, for instances that are not just numbered.
  instanceNames = value: if builtins.isInt value then map toString (lib.range 1 value) else value;

  mkLauncher =
    name: instance:
    let
      meta = cfg.apps.${name}.desktop;
    in
    pkgs.makeDesktopItem {
      name = "multi-instance-${name}-${instance}";
      desktopName = "${meta.label} ${instance}";
      genericName = meta.label;
      comment = "${meta.label}, instance ${instance}, with its own state directory";
      icon = meta.icon;
      exec = "${multi-instance}/bin/multi-instance ${name} ${instance} %F";
      categories = [ "Development" ];
      startupWMClass = meta.wmclass;
      startupNotify = true;
    };

  launchers = lib.concatLists (
    lib.mapAttrsToList (name: value: map (mkLauncher name) (instanceNames value)) cfg.instances
  );

  # Every path the programs redirect, plus the store they redirect into. The same
  # path can be listed by two programs (`CodeBuddyExtension` holds auth shared by
  # codebuddy and workbuddy), and duplicate mount units are an error.
  preserveDirectories = lib.unique (
    [
      {
        directory = cfg.stateRoot;
        mode = "0700";
      }
    ]
    ++ lib.concatLists (map (app: app.persist) (lib.attrValues cfg.apps))
  );
in
{
  options.modules.multi-instance = {
    enable = lib.mkEnableOption ''
      the `multi-instance` launcher, which runs each program in `apps` under
      bubblewrap with one state directory per instance
    '';

    stateRoot = lib.mkOption {
      type = lib.types.str;
      default = ".local/state/multi-instance";
      description = ''
        Store for per-instance state, relative to $HOME. Each instance uses
        `<stateRoot>/<app>/<instance>`. Owner-only: instances hold credentials
        and history.
      '';
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf appType;
      default = { };
      description = ''
        Programs that can be run as several instances, keyed by the name that
        `command -v` resolves. Declaring a program here also exposes its state
        paths in `preserveDirectories`.
      '';
    };

    preserveDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      readOnly = true;
      description = ''
        Preservation entries for the instance store and every `apps.*.persist`
        path, in the shape
        `preservation.preserveAt.<store>.users.<user>.directories` accepts. The
        facts live here, next to the paths themselves; the host decides which
        preservation store to put them in, because a host without the
        preservation module has no such option to declare.
      '';
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.ints.positive
          (lib.types.listOf lib.types.str)
        ]
      );
      default = { };
      description = ''
        Instances to create a desktop launcher for, keyed by program. A number
        means that many instances, named "1".."N"; a list names them explicitly.
        Only programs with `desktop` metadata are accepted.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.all (name: cfg.apps ? ${name} && cfg.apps.${name}.desktop != null) (
            lib.attrNames cfg.instances
          );
          message = "modules.multi-instance.instances: only a program in `apps` with `desktop` metadata can have a launcher";
        }
        {
          assertion = lib.all (app: lib.all (path: !lib.hasPrefix "/" path) app.paths) (
            lib.attrValues cfg.apps
          );
          message = "modules.multi-instance.apps: `paths` are relative to $HOME, so they cannot start with /";
        }
        {
          assertion = lib.all (app: app.userDataDir == null || lib.elem app.userDataDir app.paths) (
            lib.attrValues cfg.apps
          );
          message = "modules.multi-instance.apps: `userDataDir` must also be one of `paths`, so the instance has a directory to mount it from";
        }
      ];
    }

    (lib.mkIf cfg.enable {
      environment.systemPackages = [ multi-instance ] ++ launchers;
    })

    # Exposed whether or not the launcher is enabled: the paths are facts about
    # the programs, and their existing logins must survive a host that stops
    # enabling this module.
    {
      modules.multi-instance.preserveDirectories = if cfg.apps == { } then [ ] else preserveDirectories;
    }
  ];
}
