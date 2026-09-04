{
  pkgs,
  llm-agents,
  oray-tools,
  ...
}:
{
  # AI Agent Tools
  environment.systemPackages =
    with llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    [
      # Agents
      # opencode
      pkgs.opencode
    ]
    ++ [
      # oray smart plug control tool
      oray-tools.packages.${pkgs.system}.default

      # transparent proxy for remote Wayland apps over SSH (works without a desktop too)
      pkgs.waypipe
    ];
}
