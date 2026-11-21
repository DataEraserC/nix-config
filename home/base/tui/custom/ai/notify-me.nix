{
  pkgs,
  ...
}:
# `notify-me`: best-effort push notification CLI for AI agents and interactive
# use(see agents/AGENTS.md). The script is a plain shell file with no nix
# interpolation; the ntfy topic is sourced at runtime from agenix secrets.
{
  home.packages = [
    (pkgs.writeShellScriptBin "notify-me" (builtins.readFile ./notify-me.sh))
  ];
}
