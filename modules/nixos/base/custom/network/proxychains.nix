# proxychains - route CLI traffic through the local / LAN SOCKS proxies.
#
# Moved out of the shared desktop snippet into a proper module; the proxy list
# is host-agnostic (localhost + tailscale/zerotier peers), so any host can opt
# in with `modules.proxychains.enable = true`.
{ config, lib, ... }:
let
  cfg = config.modules.proxychains;
in
{
  options.modules.proxychains.enable = lib.mkEnableOption "proxychains with the shared SOCKS proxy list (chains through localhost clash/throne and LAN peers)";

  config = lib.mkIf cfg.enable {
    programs.proxychains = {
      chain.type = "dynamic";
      enable = true;
      proxies = {
        # local
        localhost_clash_proxy = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = 7890;
        };
        localhost_throne_proxy = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = 2080;
        };
        # mondrian
        mondrian_tailscale_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "100.95.92.151";
          port = 2080;
        };
        mondrian_zerotier_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "10.147.20.151";
          port = 2080;
        };
        # pstar
        pstar_tailscale_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "100.95.92.153";
          port = 2080;
        };
        pstar_zerotier_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "10.147.20.153";
          port = 2080;
        };
        # infiniti
        infiniti_tailscale_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "100.95.92.154";
          port = 2080;
        };
        infiniti_zerotier_nekobox_proxy = {
          enable = true;
          type = "socks5";
          host = "10.147.20.154";
          port = 2080;
        };
        # y9000p2025
        y9000p2025_tailscale_clash_proxy = {
          enable = true;
          type = "socks5";
          host = "100.95.92.150";
          port = 7897;
        };
        y9000p2025_zerotier_clash_proxy = {
          enable = true;
          type = "socks5";
          host = "10.147.20.150";
          port = 7897;
        };
      };
    };
  };
}
