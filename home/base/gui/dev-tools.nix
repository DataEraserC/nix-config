{
  pkgs,
  lib,
  dbx,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      qrtool # decode/encode qr code
    ]
    # mitmproxy & wireshark don't build on darwin
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      mitmproxy # http/https proxy tool
      wireshark # network analyzer
    ]
    ++ [
      # dbeaver-bin # database manager
      # NOTE: dbx-desktop can not be build currently
      # dbx.packages.${pkgs.stdenv.hostPlatform.system}.dbx-desktop
      # TODO: maybe we can move tui network tools to a better place
      traceroute # trace route
      go-graft # proxy agent in terminal
      whistle # HTTP, HTTP2, HTTPS, Websocket debugging proxy
      insomnia # REST client
      hoppscotch # Api Test Tool
    ];
}
