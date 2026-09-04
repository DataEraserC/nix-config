# Desktops hold personal data and laptops join untrusted networks, so enable the
# firewall here (repo-wide default is off, see modules/nixos/base/ssh.nix).
# SSH/Tailscale/LocalSend/Sunshine keep working via their own `openFirewall` options.
{
  networking.firewall = {
    enable = true;
    # Trust the private overlay VPNs (Tailscale / ZeroTier / EasyTier).
    # All other inbound traffic on physical interfaces is filtered by port rules.
    trustedInterfaces = [
      "tailscale0" # Tailscale
      "zt5u4z6wb4" # ZeroTier
      "easytier0" # EasyTier, see easytier.nix
    ];
  };
}
