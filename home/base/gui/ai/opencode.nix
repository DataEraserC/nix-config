{
  config,
  mylib,
  ...
}:
{
  # Global opencode config, symlinked from `opencode.json` in this directory
  # (single source of truth for the AgentRouter and CLIProxyAPI providers) into
  # `~/.config/opencode/opencode.json` so it applies on every host.
  xdg.configFile."opencode/opencode.json" = {
    source = mylib.mklinkRelativeToRoot config "home/base/gui/ai/opencode.json";
  };
}
