{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.managedLinks;
  pathType = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
  validSubpath =
    subpath: !lib.hasPrefix "/" subpath && !(builtins.elem ".." (lib.splitString "/" subpath));
  appendSubpath =
    base: subpath: if subpath == "" then toString base else "${toString base}/${subpath}";

  resolvedLinks = lib.mapAttrs (
    _name: link:
    let
      fromNamedSource = link.sourceName != null;
      linkTarget =
        if fromNamedSource then
          config.lib.mutableSources.resolve {
            name = link.sourceName;
            inherit (link) subpath fallback;
          }
        else if link.source == null then
          null
        else
          appendSubpath link.source link.subpath;
    in
    {
      inherit (link) target adoptExistingSymlink;
      inherit linkTarget;
    }
  ) (if cfg.enable then cfg.links else { });

  targets = map (link: link.target) (lib.attrValues resolvedLinks);
  desiredManifest = pkgs.writeText "managed-links.json" (
    builtins.toJSON {
      version = 1;
      allowedTargetPrefixes = cfg.allowedTargetPrefixes;
      links = resolvedLinks;
    }
  );
  activationDeps = lib.unique (
    [ "users" ] ++ lib.concatMap (link: link.after) (lib.attrValues cfg.links)
  );
in
{
  options.modules.managedLinks = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reconcile managed NixOS symlinks; disabling reconciles the desired set to empty.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nix-config/managed-links";
      description = "Persistent directory containing the last successfully applied link manifest.";
    };

    allowedTargetPrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home"
        "/var/lib"
        "/etc"
      ];
      description = "Absolute path prefixes under which managed symlink targets are permitted.";
    };

    links = lib.mkOption {
      default = { };
      description = "Named symlinks reconciled during NixOS activation.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            target = lib.mkOption {
              type = lib.types.str;
              description = "Absolute symlink path owned by this module.";
            };

            sourceName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name from modules.mutableSources.sources.";
            };

            source = lib.mkOption {
              type = pathType;
              default = null;
              description = "Direct symlink destination, mutually exclusive with sourceName.";
            };

            subpath = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Relative path appended to the named or direct source.";
            };

            fallback = lib.mkOption {
              type = pathType;
              default = null;
              description = "Per-link fallback passed to mutableSources.resolve.";
            };

            adoptExistingSymlink = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Allow first activation to replace an existing symlink at this target.";
            };

            after = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Activation script names that must prepare the target parent first.";
            };
          };
        }
      );
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (link: (link.sourceName != null) != (link.source != null)) (
          lib.attrValues cfg.links
        );
        message = "managedLinks entries must set exactly one of sourceName or source";
      }
      {
        assertion = lib.all (link: validSubpath link.subpath) (lib.attrValues cfg.links);
        message = "managedLinks subpaths must be relative and must not contain '..'";
      }
      {
        assertion = lib.all (target: lib.hasPrefix "/" target && target != "/") targets;
        message = "managedLinks targets must be absolute non-root paths";
      }
      {
        assertion =
          lib.hasPrefix "/" cfg.stateDirectory
          && cfg.stateDirectory != "/"
          && lib.all (prefix: lib.hasPrefix "/" prefix && prefix != "/") cfg.allowedTargetPrefixes;
        message = "managedLinks stateDirectory and allowedTargetPrefixes must be absolute non-root paths";
      }
      {
        assertion = lib.all (
          target:
          lib.any (
            prefix: target == prefix || lib.hasPrefix "${lib.removeSuffix "/" prefix}/" target
          ) cfg.allowedTargetPrefixes
        ) targets;
        message = "managedLinks targets must be inside allowedTargetPrefixes";
      }
      {
        assertion = lib.length targets == lib.length (lib.unique targets);
        message = "managedLinks targets must be unique";
      }
      {
        assertion = lib.all (link: link.linkTarget != null) (lib.attrValues resolvedLinks);
        message = "managedLinks sources must resolve to an external path or fallback";
      }
    ];

    system.build.managedLinksManifest = desiredManifest;

    system.activationScripts.managedLinks = {
      deps = activationDeps;
      text = ''
        if [ "''${IN_NIXOS_SYSTEMD_STAGE1:-}" != true ]; then
          install -d -m 0700 ${lib.escapeShellArg cfg.stateDirectory}
          ${pkgs.python3}/bin/python ${./managed_links.py} \
            --desired ${desiredManifest} \
            --state ${lib.escapeShellArg "${cfg.stateDirectory}/manifest.json"}
        fi
      '';
    };
  };
}
