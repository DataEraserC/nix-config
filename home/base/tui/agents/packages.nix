{
  pkgs,
  llm-agents,
  nur-ryan4yin,
  ...
}:
let
  agentPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    # Agents
    agentPackages.codex
    agentPackages.opencode2
    agentPackages.pi
    # antigravity-cli (`agy`): installed for dsh/modlens, NOT as a standalone
    # agent CLI like opencode/kimi-code. modlens's `antigravity-cli` vision
    # provider spawns `agy` as a subprocess from PATH, so it must be on the
    # system profile. State (OAuth login, config, logs) lives in ~/.gemini,
    # which preservation.nix keeps across boots.
    pkgs.antigravity-cli
    # NOTE: disable bcs i use dsh.nix for dsh
    # dsh from nur-packages: llm-agents.nix's dsh cannot boot on nixpkgs node
    # (node-addon-require-builtin probe), this one shims it.
    # nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.dsh

    # Docs lookup CLI behind the find-docs skill (agents/skills/find-docs). The skill's flags are
    # written against this package, not against upstream's npx instructions.
    pkgs.ctx7

    # MCP servers, configured project-scoped in opencode.jsonc / .codex/config.toml
    pkgs.mcp-grafana
  ];
}
