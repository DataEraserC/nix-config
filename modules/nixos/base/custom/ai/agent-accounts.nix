# ===============================================================================
#
# Agent accounts - run each AI agent / IDE with one state directory per account.
#
# The mechanism lives in modules/multi-instance: every app below keeps its state
# in a path hardcoded under $HOME, and no single upstream switch covers them, so
# each account gets a directory bind-mounted over each path. Nothing here
# patches or wraps a package.
#
# Usage
#   multi-instance <app> <account> [args...]
#   multi-instance codebuddy-acp work
#   multi-instance trae-cn 1
#
# An account always starts empty. Nothing is copied out of the app's existing
# state under $HOME, so a plain `trae-cn` keeps its own login untouched and an
# account never inherits it. Configuring `desktopAccounts` gives each account a
# launcher entry (`Trae CN 1`, `Trae CN 2`, ...).
# ===============================================================================
{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.agent-accounts;

  codebuddyApp = {
    executable = "codebuddy-acp";
    stateDirectoryKey = "codebuddy";
    paths = [
      ".codebuddy"
      ".local/share/CodeBuddyExtension"
    ];
    persist = [
      {
        directory = ".codebuddy";
        mode = "0700";
      }
      {
        directory = ".local/share/CodeBuddyExtension";
        mode = "0700";
      }
    ];
  };

  # The one table: where each app keeps its state, which of those paths survive a
  # tmpfs root, and how an account window is recognised by the desktop. An
  # account is added by changing `desktopAccounts`, not this table.
  apps = {
    # `codebuddy-acp` is the canonical app key. The old CLI name is an alias
    # below because WebMux launch-configs.json is seed-once; it does not create
    # a second app/state declaration.
    codebuddy-acp = codebuddyApp;

    # Its launcher exports these paths unconditionally.
    codearts = {
      paths = [ ".codeartsdoer" ];
      persist = [
        {
          directory = ".codeartsdoer";
          mode = "0700";
        }
      ];
    };

    # The shared Tencent auth (codebuddy-acp + workbuddy) is built from os.homedir(),
    # so no environment variable reaches it; mounting over each path redirects
    # all of them the same way. ~/.sheetagent holds logs only and ~/WorkBuddy is
    # an empty scaffold, so neither is preserved.
    workbuddy = {
      paths = [
        ".workbuddy"
        ".sheetagent"
        "WorkBuddy"
        ".local/share/CodeBuddyExtension"
      ];
      persist = [
        {
          directory = ".workbuddy";
          mode = "0700";
        }
        {
          directory = ".local/share/CodeBuddyExtension";
          mode = "0700";
        }
      ];
      desktop = {
        label = "WorkBuddy";
        icon = "workbuddy";
        wmclass = "workbuddy";
      };
    };

    # The international build of the same app (nur-DataEraserC.workbuddy-ai). Its
    # `dataFolderName` moves the main state to ~/.workbuddy-ai, but it still
    # writes a device id and startup logs to ~/.workbuddy and reaches auth through
    # ~/.local/share/CodeBuddyExtension as the CN build does, so all three are
    # per-instance: an international account must not share state with a CN one.
    workbuddy-ai = {
      paths = [
        ".workbuddy-ai"
        ".workbuddy"
        ".sheetagent"
        "WorkBuddy"
        ".local/share/CodeBuddyExtension"
      ];
      persist = [
        {
          directory = ".workbuddy-ai";
          mode = "0700";
        }
        {
          directory = ".workbuddy";
          mode = "0700";
        }
        {
          directory = ".local/share/CodeBuddyExtension";
          mode = "0700";
        }
      ];
      desktop = {
        label = "WorkBuddy International";
        icon = "workbuddy-ai";
        # The window class comes from the app's own name, which the package's
        # rename does not change, so both builds report "workbuddy".
        wmclass = "workbuddy";
      };
    };

    # It overwrites --user-data-dir, so ~/.config/LobsterAI is the only profile
    # path; ~/lobsterai is the default working directory it creates at startup.
    # Its OpenClaw gateway keeps a startup-migration lock and state database under
    # /tmp, which is private per instance, so no further entry is needed here.
    lobsterai = {
      paths = [
        ".config/LobsterAI"
        "lobsterai"
      ];
      persist = [
        {
          directory = ".config/LobsterAI";
          mode = "0700";
        }
        "lobsterai"
      ];
      desktop = {
        label = "LobsterAI";
        icon = "lobsterai";
        wmclass = "LobsterAI";
      };
    };

    # Its single-instance lock is named after the user data directory, so two
    # accounts would share one window without `userDataDir`.
    trae-cn = {
      paths = [
        ".trae-cn"
        ".config/Trae CN"
      ];
      userDataDir = ".config/Trae CN";
      persist = [
        ".trae-cn"
        {
          directory = ".config/Trae CN";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Trae CN";
        icon = "trae-cn";
        wmclass = "Trae CN";
      };
    };

    trae = {
      paths = [
        ".trae"
        ".config/Trae"
      ];
      userDataDir = ".config/Trae";
      persist = [
        ".trae"
        {
          directory = ".config/Trae";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Trae";
        icon = "trae";
        wmclass = "Trae";
      };
    };

    # The CN and international editions are one AppImage (same productName, no
    # dataFolderName), so one GUI app serves both: ~/.zcode holds CLI sessions,
    # wiki and agent runtimes; ~/.config/ZCode is the Electron user data
    # directory. Its single-instance lock is named after the user data
    # directory, so two accounts would share one window without userDataDir.
    zcode = {
      paths = [
        ".zcode"
        ".config/ZCode"
      ];
      userDataDir = ".config/ZCode";
      persist = [
        {
          # 0700 so the GUI entry collapses into the zcode-cli one below
          # (lib.unique needs identical values); .zcode holds credentials.
          directory = ".zcode";
          mode = "0700";
        }
        {
          directory = ".config/ZCode";
          mode = "0700";
        }
      ];
      desktop = {
        label = "ZCode";
        icon = "zcode";
        wmclass = "ZCode";
      };
    };

    # The ACP adapter (what WebMux drives) and the vendor TUI (what a terminal
    # runs) are separate binaries, but both instance forms share one state key
    # so a session created through the ACP bridge can be resumed with
    # `zcode-cli --resume` in the TUI and the other way round. Only ~/.zcode is
    # redirected: the GUI app above owns ~/.config/ZCode. The executable
    # defaults to the app key: the desktop package owns bin/zcode, so the CLI
    # wrapper is the separately named zcode-cli.
    zcode-cli = {
      stateDirectoryKey = "zcode-cli";
      paths = [
        ".zcode"
      ];
      persist = [
        {
          directory = ".zcode";
          mode = "0700";
        }
      ];
    };

    zcode-acp = {
      executable = "zcode-acp-server";
      stateDirectoryKey = "zcode-cli";
      paths = [
        ".zcode"
      ];
      persist = [
        {
          directory = ".zcode";
          mode = "0700";
        }
      ];
    };

    # Qoder has two product lines, each with a CN and an international build.
    # The IDE stores state in ~/.qoder(-cn) + ~/.config/Qoder(CN); the Electron
    # workbench uses ~/.qoder(-cn) + ~/.config/com.qoder(cn).app.stable. The
    # shared ~/.qoder directory is the agent resource tree used by both
    # products; per-app accounts still get their own copy because the app key
    # differs.
    qoder-ide = {
      executable = "qoder-ide";
      paths = [
        ".qoder"
        ".config/Qoder"
      ];
      userDataDir = ".config/Qoder";
      persist = [
        ".qoder"
        {
          directory = ".config/Qoder";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Qoder IDE";
        icon = "qoder-ide";
        wmclass = "qoder-ide";
      };
    };

    qoder = {
      executable = "qoder";
      stateDirectoryKey = "qoder-app";
      paths = [
        ".qoder"
        ".config/com.qoder.app.stable"
      ];
      userDataDir = ".config/com.qoder.app.stable";
      persist = [
        ".qoder"
        {
          directory = ".config/com.qoder.app.stable";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Qoder";
        icon = "qoder";
        wmclass = "qoder";
      };
    };

    qoder-cn-ide = {
      executable = "qoder-cn-ide";
      stateDirectoryKey = "qoder-cn";
      paths = [
        ".qoder-cn"
        ".config/QoderCN"
      ];
      userDataDir = ".config/QoderCN";
      persist = [
        ".qoder-cn"
        {
          directory = ".config/QoderCN";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Qoder CN IDE";
        icon = "qoder-cn-ide";
        wmclass = "qoder-cn-ide";
      };
    };

    qoder-cn = {
      executable = "qoder-cn";
      stateDirectoryKey = "qoder-cn-app";
      paths = [
        ".qoder-cn"
        ".config/com.qodercn.app.stable"
      ];
      userDataDir = ".config/com.qodercn.app.stable";
      persist = [
        ".qoder-cn"
        {
          directory = ".config/com.qodercn.app.stable";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Qoder CN";
        icon = "qoder-cn";
        wmclass = "qoder-cn";
      };
    };

    # The AutoClaw launchers pin XDG_CONFIG_HOME per edition; the app writes
    # two sibling directories under it (AutoClaw plus AutoClaw-official for CN
    # or AutoClaw-oversea-official for International), which are the per-account
    # state.
    autoclaw-cn = {
      executable = "autoclaw-cn";
      paths = [
        ".config/autoclaw-cn/AutoClaw"
        ".config/autoclaw-cn/AutoClaw-official"
      ];
      userDataDir = ".config/autoclaw-cn/AutoClaw-official";
      persist = [
        {
          directory = ".config/autoclaw-cn/AutoClaw";
          mode = "0700";
        }
        {
          directory = ".config/autoclaw-cn/AutoClaw-official";
          mode = "0700";
        }
      ];
      desktop = {
        label = "AutoClaw CN";
        icon = "autoclaw-cn";
        wmclass = "AutoClaw";
      };
    };

    autoclaw-intl = {
      executable = "autoclaw-intl";
      paths = [
        ".config/autoclaw-intl/AutoClaw"
        ".config/autoclaw-intl/AutoClaw-oversea-official"
      ];
      userDataDir = ".config/autoclaw-intl/AutoClaw-oversea-official";
      persist = [
        {
          directory = ".config/autoclaw-intl/AutoClaw";
          mode = "0700";
        }
        {
          directory = ".config/autoclaw-intl/AutoClaw-oversea-official";
          mode = "0700";
        }
      ];
      desktop = {
        label = "AutoClaw";
        icon = "autoclaw-intl";
        wmclass = "AutoClaw";
      };
    };

    # The profile root is ~/.config/office-raccoon: it holds userData, sessions
    # and logs, and the app rejects it unless it is owner-only and not a
    # symlink (multi-instance creates each state directory 0700 for that
    # reason). ~/.box-agent is the agent home: the login (config/auth.json),
    # model profiles, skills, run sockets and the provisioned Python/Node
    # runtime all live there, so without it every account opens signed in as
    # the same user. ~/RaccoonWork is the default agent workspace and
    # ~/.openclaw / ~/.hermes are the bundled agent runtimes' homes.
    xiaohuanxiong = {
      paths = [
        ".config/office-raccoon"
        ".box-agent"
        "RaccoonWork"
        ".openclaw"
        ".hermes"
      ];
      persist = [
        {
          directory = ".config/office-raccoon";
          mode = "0700";
        }
        {
          directory = ".box-agent";
          mode = "0700";
        }
        "RaccoonWork"
        {
          directory = ".openclaw";
          mode = "0700";
        }
        {
          directory = ".hermes";
          mode = "0700";
        }
      ];
      desktop = {
        label = "Raccoon Work";
        icon = "raccoon-ai";
        wmclass = "raccoon-ai";
      };
    };
  };
in
{
  options.modules.agent-accounts = {
    enable = lib.mkEnableOption ''
      the `multi-instance` launcher that runs the AI agents and IDEs above under
      bubblewrap with one state directory per account
    '';

    desktopAccounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.ints.positive
          (lib.types.listOf lib.types.str)
        ]
      );
      default = { };
      example = {
        workbuddy = 6;
        lobsterai = 2;
        trae-cn = [
          "work"
          "home"
        ];
      };
      description = ''
        Accounts to create a desktop launcher for, keyed by app. A number means
        that many accounts, named "1".."N"; a list names them explicitly. Each
        account gets one entry labelled "<app> <account>" that starts the app
        through `multi-instance` in its own state directory. Only the GUI apps
        have a launcher: workbuddy, workbuddy-ai, lobsterai, trae-cn, trae,
        zcode, qoder, qoder-ide, qoder-cn, qoder-cn-ide,
        autoclaw-cn, autoclaw-intl, xiaohuanxiong.
      '';
    };
  };

  # Declared whether or not the launcher is enabled: the paths are facts about
  # the apps, and their logins must survive a host that stops enabling this
  # module.
  config = {
    modules.multi-instance.apps = apps;
    modules.multi-instance.aliases.codebuddy = "codebuddy-acp";
    modules.multi-instance.aliases.zcode-intl = "zcode";
    modules.multi-instance.enable = cfg.enable;
    modules.multi-instance.instances = cfg.desktopAccounts;
  };
}
