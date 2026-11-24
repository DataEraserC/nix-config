# WARN: do not use this file
# Use nixos_agenix.nix or nixos_sopsnix.nix
{
  lib,
  config,
  pkgs,
  agenix,
  myvars,
  ...
}@args:
with lib;
let
  mysecrets = "${args.mysecrets}/agenix";
  cfg = config.modules.secrets;

  enabledServerSecrets =
    cfg.server.application.enable
    || cfg.server.network.enable
    || cfg.server.operation.enable
    || cfg.server.kubernetes.enable
    || cfg.server.webserver.enable
    || cfg.server.storage.enable;

  noaccess = {
    mode = "0000";
    owner = "root";
  };
  high_security = {
    mode = "0500";
    owner = "root";
  };
  user_readable = {
    mode = "0500";
    owner = myvars.username;
  };
  MkPermAttr = username: mode: {
    mode = mode;
    owner = username;
  };
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";

    server.network.enable = mkEnableOption "NixOS Secrets for Network Servers";
    server.application.enable = mkEnableOption "NixOS Secrets for Application Servers";
    server.operation.enable = mkEnableOption "NixOS Secrets for Operation Servers(Backup, Monitoring, etc)";
    server.kubernetes.enable = mkEnableOption "NixOS Secrets for Kubernetes";
    server.webserver.enable = mkEnableOption "NixOS Secrets for Web Servers(contains tls cert keys)";
    server.storage.enable = mkEnableOption "NixOS Secrets for HDD Data's LUKS Encryption";

    preservation.enable = mkEnableOption "whether use preservation and ephemeral root file system";
  };

  config = mkIf (cfg.desktop.enable || enabledServerSecrets) (mkMerge [
    {
      environment.systemPackages = [
        agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
      ];

      # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
      age.identityPaths =
        if cfg.preservation.enable then
          [
            # To decrypt secrets on boot, this key should exists when the system is booting,
            # so we should use the real key file path(prefixed by `/persistent/`) here, instead of the path mounted by preservation.
            "/persistent/etc/ssh/ssh_host_ed25519_key" # Linux
          ]
        else
          [
            "/etc/ssh/ssh_host_ed25519_key"
          ];

      # secrets that are used by all nixos hosts
      age.secrets = {
        "nix-access-tokens" = {
          file = "${mysecrets}/server/nix-access-tokens.age";
        }
        # access-token needs to be readable by the user running the `nix` command
        // user_readable;
      };

      assertions = [
        {
          # This expression should be true to pass the assertion
          # WARNING: we bypass this on my secret bcs we only have a computer without surrounding facilities
          assertion = !(cfg.desktop.enable && enabledServerSecrets) || true;
          message = "Enable either desktop or server's secrets, not both!";
        }
      ];
    }

    (mkIf cfg.desktop.enable {
      age.secrets = {
        # ---------------------------------------------
        # No discretionary access; privileged root can still bypass file modes.
        # ---------------------------------------------

        # .age means the decrypted file is still encrypted by age(via a passphrase)
        "nix-gpg-subkeys.priv.age" = {
          file = "${mysecrets}/desktop/nix-gpg-subkeys-2024-01-27.priv.age.age";
        }
        // noaccess;

        # Used only by NixOS Modules

        "rclone.conf" = {
          file = "${mysecrets}/desktop/rclone.conf.age";
        }
        // high_security;

        # ---------------------------------------------
        # user can read this file.
        # ---------------------------------------------

        "ssh-key-romantic" = {
          file = "${mysecrets}/desktop/ssh-key-romantic.age";
        }
        // user_readable;

        "idols-ai_id_rsa" = {
          file = "${mysecrets}/idols-ai_id_rsa.age";
        }
        // user_readable;

        "idols-ai_id_ed25519" = {
          file = "${mysecrets}/idols-ai_id_ed25519.age";
        }
        // user_readable;

        # alias-for-work
        "alias-for-work.nushell" = {
          file = "${mysecrets}/alias-for-work.nushell.age";
        }
        // user_readable;

        # work git identity, symlinked to ~/work/.gitconfig by home-manager
        "work-gitconfig" = {
          file = "${mysecrets}/desktop/work-gitconfig.age";
        }
        // user_readable;
        "alias-for-work.bash" = {
          file = "${mysecrets}/alias-for-work.bash.age";
        }
        // user_readable;
        # I do not have server for router request so I use dae locally
        "clash.dae" = {
          file = "${mysecrets}/clash.dae.age";
        }
        // high_security;
        "dae.dae" = {
          file = "${mysecrets}/dae.dae.age";
        }
        // high_security;
        "dae-subscription.dae" = {
          file = "${mysecrets}/server/dae-subscription.dae.age";
        }
        // high_security;
        # bcrypt hash line for the Caddy Basic Auth in front of Sub-Store
        # (never the plaintext password); readable by root and the caddy group.
        "sub-store.caddy" = mkIf config.services.caddy.enable {
          file = "${mysecrets}/server/sub-store.caddy.age";
          mode = "0440";
          owner = "root";
          group = "caddy";
        };
        "cpolar.yml" = {
          file = "${mysecrets}/cpolar.yml.age";
        }
        // (MkPermAttr "cpolar" "0700");
        # cpolar login credentials, only readable by the cpolar user (and root).
        "cpolar-status.env" = {
          file = "${mysecrets}/cpolar-status.env.age";
          mode = "0700";
          owner = "cpolar";
          group = "cpolar";
        };
        # host-readable ntfy topic, replaces the ntfy_topic in alias-for-work.bash.
        "ntfy-topic.env" = {
          file = "${mysecrets}/ntfy-topic.env.age";
          mode = "0644";
          owner = myvars.username;
          group = myvars.username;
        };
        # ACB 的静态密钥：模型网关 key、控制台/snowluma token、opencode 密码。
        # 只给运行用户读；config.toml 里写 ${...} 占位符。
        "acb.env" = {
          file = "${mysecrets}/acb.env.age";
          mode = "0400";
          owner = myvars.username;
          group = myvars.username;
        };
        # ACB 带外通知（ntfy）的 topic，仅运行用户可读；由
        # modules.acb.notifications.topicSecret 挂进 acb-bridge 的 EnvironmentFile。
        "ntfy-acb-topic.env" = {
          file = "${mysecrets}/ntfy-acb-topic.env.age";
          mode = "0400";
          owner = myvars.username;
          group = myvars.username;
        };
        "alist-jwt" = {
          file = "${mysecrets}/alist-jwt.age";
        }
        // (MkPermAttr "alist" "0700");
        "frp_aliyun2025.toml" = {
          file = "${mysecrets}/frp_aliyun2025.toml.age";
        }
        // high_security;
        "easytier-env" = {
          file = "${mysecrets}/easytier.env.age";
        }
        // high_security;
        # gost SOCKS5 proxy credentials, one line of "<username> <password>"
        # (space separated); read by the gost auther and chain connector of
        # modules.gost-proxy (both the listener and the chained forwarder).
        "gost-proxy.auth" = mkIf config.modules.gost-proxy.enable (
          { file = "${mysecrets}/gost-proxy.auth.age"; } // high_security
        );
        "ecc-ca.key" = {
          file = "${mysecrets}/ecc-ca.key.age";
        }
        // high_security;
        "ecc-server.key" = {
          file = "${mysecrets}/ecc-server.key.age";
        }
        // high_security;
        "cliproxyapi-management.key" = {
          file = "${mysecrets}/cliproxyapi-management.key.age";
          mode = "0600";
          owner = "cliproxyapi";
          group = "cliproxyapi";
        };
        "m365-copilot2api-admin-password" = {
          file = "${mysecrets}/m365-copilot2api-admin-password.age";
          mode = "0600";
          owner = "m365-copilot2api";
          group = "m365-copilot2api";
        };
        "m365-copilot2api-master-key" = {
          file = "${mysecrets}/m365-copilot2api-master-key.age";
          mode = "0600";
          owner = "m365-copilot2api";
          group = "m365-copilot2api";
        };
        "opencode2api-webui-password" = {
          file = "${mysecrets}/opencode2api-webui-password.age";
          mode = "0600";
          owner = "opencode2api";
          group = "opencode2api";
        };
        "agent2api-admin-password" = mkIf config.modules.agent2api.enable {
          file = "${mysecrets}/agent2api-admin-password.age";
          mode = "0600";
          owner = "agent2api";
          group = "agent2api";
        };
        "new-api-session-secret" = {
          file = "${mysecrets}/new-api-session-secret.age";
          mode = "0600";
          owner = "new-api";
          group = "new-api";
        };
        "workbuddy2api-api-key" = mkIf config.modules.workbuddy2api.enable {
          file = "${mysecrets}/workbuddy2api-api-key.age";
          mode = "0600";
          owner = "workbuddy2api";
          group = "workbuddy2api";
        };
      };

      # place secrets in /etc/
      environment.etc = {
        "agenix/rclone.conf" = {
          source = config.age.secrets."rclone.conf".path;
        };

        "agenix/ssh-key-romantic" = {
          source = config.age.secrets."ssh-key-romantic".path;
          mode = "0600";
          user = myvars.username;
        };

        "agenix/idols-ai_id_rsa" = {
          source = config.age.secrets."idols-ai_id_rsa".path;
          mode = "0600";
          user = myvars.username;
        };

        "agenix/idols-ai_id_ed25519" = {
          source = config.age.secrets."idols-ai_id_ed25519".path;
          mode = "0600";
          user = myvars.username;
        };

        "agenix/nix-gpg-subkeys.priv.age" = {
          source = config.age.secrets."nix-gpg-subkeys.priv.age".path;
          mode = "0000";
        };

        # The following secrets are used by home-manager modules
        # So we need to make then readable by the user
        "agenix/alias-for-work.nushell" = {
          source = config.age.secrets."alias-for-work.nushell".path;
          mode = "0644"; # both the original file and the symlink should be readable and executable by the user
        };
        "agenix/alias-for-work.bash" = {
          source = config.age.secrets."alias-for-work.bash".path;
          mode = "0644"; # both the original file and the symlink should be readable and executable by the user
        };
        "agenix/cpolar-status.env" = {
          source = config.age.secrets."cpolar-status.env".path;
          mode = "0700";
          user = "cpolar";
          group = "cpolar";
        };
        "agenix/ntfy-topic.env" = {
          source = config.age.secrets."ntfy-topic.env".path;
          mode = "0644";
          user = myvars.username;
          group = myvars.username;
        };

        # Used by a home-manager module, so it must be readable by the user.
        # Setting `mode` makes environment.etc copy the file instead of
        # symlinking the runtime secret, so the owner must be set as well —
        # otherwise it becomes a world-readable, root-owned copy of the secret.
        "agenix/work-gitconfig" = {
          source = config.age.secrets."work-gitconfig".path;
          mode = "0400";
          user = myvars.username;
        };
      };
    })

    (mkIf cfg.server.network.enable {
      age.secrets = {
        "dae-subscription.dae" = {
          file = "${mysecrets}/server/dae-subscription.dae.age";
        }
        // high_security;
      };
    })

    (mkIf cfg.server.application.enable {
      age.secrets = {
        "transmission-credentials.json" = {
          file = "${mysecrets}/server/transmission-credentials.json.age";
        }
        // high_security;

        "sftpgo.env" = {
          file = "${mysecrets}/server/sftpgo.env.age";
          mode = "0400";
          owner = "sftpgo";
        };

        # RustFS root credentials as a systemd EnvironmentFile consumed by
        # services.rustfs: RUSTFS_ACCESS_KEY / RUSTFS_SECRET_KEY.
        "rustfs.env" = {
          file = "${mysecrets}/server/rustfs.env.age";
          mode = "0400";
          owner = "root";
        };
      };
    })

    (mkIf cfg.server.operation.enable {
      age.secrets = {
        "grafana-admin-password" = {
          file = "${mysecrets}/server/grafana-admin-password.age";
          mode = "0400";
          owner = "grafana";
        };
        "grafana-secret-key" = {
          file = "${mysecrets}/server/grafana-secret-key.age";
          mode = "0400";
          owner = "grafana";
        };

        "alertmanager.env" = {
          file = "${mysecrets}/server/alertmanager.env.age";
        }
        // high_security;
      };
    })

    (mkIf cfg.server.kubernetes.enable {
      age.secrets = {
        "k3s-test-1-token" = {
          file = "${mysecrets}/server/k3s-test-1-token.age";
        }
        // high_security;
      };
    })

    (mkIf cfg.server.webserver.enable {
      age.secrets = {
        "caddy-ecc-server.key" = {
          file = "${mysecrets}/certs/ecc-server.key.age";
          mode = "0400";
          owner = "caddy";
        };
        "postgres-ecc-server.key" = {
          file = "${mysecrets}/certs/ecc-server.key.age";
          mode = "0400";
          owner = "postgres";
        };
        "cpolar.yml" = {
          file = "${mysecrets}/cpolar.yml.age";
        }
        // (MkPermAttr "cpolar" "0700");
        "alist-jwt" = {
          file = "${mysecrets}/alist-jwt.age";
        }
        // (MkPermAttr "alist" "0700");

        # Cloudflare API token (Zone -> DNS -> Edit on `writefor.fun`) consumed
        # by security.acme (lego) as its environment file for the ACME DNS-01
        # challenge on publicly-trusted sites. lego runs as root here.
        "cloudflare-dns-api-token" = {
          file = "${mysecrets}/server/cloudflare-dns-api-token.env.age";
          mode = "0400";
          owner = "root";
        };
      };
    })

    (mkIf cfg.desktop.enable {
      # Desktops use their own restic repository password, NOT the homelab's:
      # the backup server holds the homelab one, so a shared password would let
      # that server decrypt desktop data.
      age.secrets."restic-password" = {
        file = "${mysecrets}/desktop/restic-password-desktop.age";
        mode = "0400";
        owner = "root";
      };
      # credentials for the restic REST server that receives this backup
      age.secrets."restic-rest-credentials" = {
        file = "${mysecrets}/desktop/restic-rest-credentials.age";
        mode = "0400";
        owner = "root";
      };
    })

    (mkIf cfg.server.storage.enable {
      # the homelab's restic repository password, shared by the homelab hosts
      # (this host holds it, so it can copy/verify homelab repositories)
      age.secrets."restic-password" = {
        file = "${mysecrets}/server/restic-password-homelab.age";
        mode = "0400";
        owner = "root";
      };
      # htpasswd for the restic REST server this host runs; the service runs as
      # the unprivileged `restic` user, which must be able to read it
      age.secrets."restic-rest-htpasswd" = {
        file = "${mysecrets}/server/restic-rest-htpasswd.age";
        mode = "0400";
        owner = "restic";
      };
    })

    (mkIf cfg.server.storage.enable {
      age.secrets = {
        "hdd-luks-crypt-key" = {
          file = "${mysecrets}/server/hdd-luks-crypt-key.age";
          mode = "0400";
          owner = "root";
        };
        # restic repository password (used by modules.restic-backup). Gated
        # separately below so desktops get it without enabling a server group.
      };

      # place secrets in /etc/
      environment.etc = {
        "agenix/hdd-luks-crypt-key" = {
          source = config.age.secrets."hdd-luks-crypt-key".path;
          mode = "0400";
          user = "root";
        };
      };
    })
  ]);
}
