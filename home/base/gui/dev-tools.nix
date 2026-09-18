{
  pkgs,
  llm-agents,
  dbx,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      # dbeaver-bin # database manager
      dbx.packages.${pkgs.stdenv.hostPlatform.system}.dbx-desktop
      # TODO: maybe we can move tui network tools to a better place
      traceroute # trace route
      go-graft # proxy agent in terminal
      bettercap # mitm proxy tool
      whistle # HTTP, HTTP2, HTTPS, Websocket debugging proxy
      insomnia # REST client
      hoppscotch # Api Test Tool
      # ciscoPacketTracer8 # computer network tool
      # these is gns3, an alternative to packet tracer
      # gns3-server
      # gns3-gui
      linux-wifi-hotspot
      hostapd

      mitmproxy # http/https proxy tool
      wireshark # network analyzer
      qrtool # decode/encode qr code
    ]
    ++ (with pkgs; [
      # mqttx # MQTT client
    ])
    # AI Agent Tools
    ++ (with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      # Agents
      codex
      cursor-cli
      claude-code
      # opencode
      pkgs.opencode
      kimi-code

      # Utilities
      rtk # CLI proxy that reduces LLM token consumption
    ]);
}
