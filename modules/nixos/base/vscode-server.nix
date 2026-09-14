{
  config,
  lib,
  pkgs,
  vscode-server,
  ...
}:
# WORKAROUND: make nixos-vscode-server's watcher ignore hidden directories
# below `~/.vscode-server/cli/servers/` (currently `.locks`).
#
# Reason:
#   Recent VS Code versions keep per-version *lock* files in the hidden
#   `~/.vscode-server/cli/servers/.locks` directory, and they extract every
#   new server into `cli/servers/Stable-<hash>.staging-<uuid>` before
#   renaming it into place.
#
#   Upstream's watcher (pkgs/auto-fix-vscode-server.nix) treats *every* new
#   directory below `cli/servers` as a server installation: it creates a
#   placeholder `<dir>/server/node` and then blocks forever in
#   `inotifywait -qq -e DELETE_SELF <placeholder>`, because nothing ever
#   replaces that placeholder inside `.locks`.  While the watcher is stuck,
#   the server installation that follows is never patched, so the bundled
#   Node.js stays a foreign dynamically linked executable and the client
#   aborts with:
#
#     Could not start dynamically linked executable: .../server/node
#     ... (code 127)
#
#   Observed on idols-ai: the service logged "VS Code server is being
#   installed in .../cli/servers/.locks/server..." and the placeholder
#   `.locks/server/node` was still present minutes later, while the real
#   `Stable-645f29cc....staging-...` installation was never patched.
#
#   The three patterns substituted below are written against
#   nixos-vscode-server @ 2f984dfbe7e5271b5c413d3e734374cc1306c921 (see
#   flake.lock).  They use `--replace-fail` on purpose: if upstream changes
#   the generated script, the build fails loudly instead of silently
#   regressing to the broken behaviour described above.
#
# When to remove:
#   Delete this whole `let` block and the `ExecStart` override below once
#   ALL of the following are true:
#   1. `nixos-vscode-server` (or whatever module replaces it) stops treating
#      hidden directories as server installations, e.g. its `find` /
#      `inotifywait` invocations skip `-name ".*"` themselves, or it watches
#      the staging directory directly instead of `cli/servers`.
#   2. `nix flake update vscode-server` no longer makes the derivation below
#      fail with `--replace-fail`.  That failure IS the signal to re-check
#      upstream: if upstream fixed the hidden-directory handling, remove the
#      workaround; if it merely reworded the script, adapt the patterns.
#
#   This workaround also stops being sufficient (not wrong, just useless) if:
#   - VS Code stops extracting the server inside `cli/servers`.  The watcher
#     only listens for `CREATE,ISDIR`, while an installation renamed into
#     place from elsewhere emits `MOVED_TO,ISDIR` and would be missed.
#   - VS Code adds a non-hidden helper directory below `cli/servers` that
#     never receives a `node` file: the watcher would stall on it exactly
#     like it did on `.locks`.
#   - The server starts shipping an interpreter/libraries that work on NixOS
#     as-is, or `services.vscode-server.enableFHS` is switched on, making the
#     node patch unnecessary in the first place.
#
# TODO: remove this workaround once upstream handles the `.locks` directory
#       (or the whole `cli/servers` layout) itself.
let
  # The upstream module builds its watcher from its own tree with
  # `pkgs.callPackage`, so the only way to change the generated script is to
  # post-process it.
  upstream = pkgs.callPackage "${vscode-server}/pkgs/auto-fix-vscode-server.nix" (
    removeAttrs config.services.vscode-server [ "enable" ]
  );

  # Skip hidden directories in the initial scan of existing installations and
  # in the loop reacting to new directories.
  auto-fix-vscode-server =
    pkgs.runCommandLocal "auto-fix-vscode-server"
      {
        nativeBuildInputs = [
          pkgs.gnugrep
          pkgs.gnused
        ];
        meta = upstream.meta or { };
      }
      ''
        mkdir -p $out/bin
        cp ${upstream}/bin/auto-fix-vscode-server $out/bin/auto-fix-vscode-server
        chmod u+w $out/bin/auto-fix-vscode-server

        substituteInPlace $out/bin/auto-fix-vscode-server \
          --replace-fail \
            'find "$bins_dir_1" -mindepth 1 -maxdepth 1 -type d -printf' \
            'find "$bins_dir_1" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf' \
          --replace-fail \
            'find "$bins_dir_2" -mindepth 1 -maxdepth 1 -type d -printf' \
            'find "$bins_dir_2" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -printf' \
          --replace-fail \
            'while IFS=: read -r bins_dir bin event; do' \
            'while IFS=: read -r bins_dir bin event; do if [[ $bin == .* ]]; then continue; fi'
      '';
in
{
  imports = [ vscode-server.nixosModules.default ];

  options.modules.vscode-server = {
    enable = lib.mkEnableOption "NixOS vs-code server";
  };

  config = lib.mkIf config.modules.vscode-server.enable {
    services.vscode-server.enable = true;

    # Use the patched watcher instead of the one shipped by the upstream module.
    systemd.user.services.auto-fix-vscode-server.serviceConfig.ExecStart = lib.mkForce (
      "${auto-fix-vscode-server}/bin/auto-fix-vscode-server"
    );
  };
}
