{ pkgs-master, ... }:
# NOTE: There is a known pitfall with mihomo's fake-IP for IPv6
# (fake-ip-range6: fdfe:dcba:9876::/64): TCP connections to IPv6 fake-IPs are
# not proxied correctly and simply hang until connect() times out.
# Clients without a fast IPv4 fallback stall for ~2 minutes per attempt:
# every git remote operation (fetch/pull/push alike, they all go through ssh)
# hangs on "Connecting to ssh.github.com [fdfe:dcba:9876::x] port 443"
# before falling back to IPv4.
# Browsers recover silently thanks to Happy Eyeballs (RFC 8305: when a name
# resolves to both IPv4 and IPv6, the client tries one stack first, then races
# the other after a ~50ms delay and keeps whichever connects first).
# Fix: disable IPv6 in Clash Verge's DNS/TUN settings (confirmed working);
# or work around per-client, e.g. `AddressFamily inet` in ssh_config
# (see home/base/tui/ssh.nix).
#
# NOTE: GNOME top-bar tray menu stall (diagnosed on clash-verge-rev 2.5.2 +
# GNOME Shell 50.4 + appindicator extension v64): clicking the tray icon at
# the right of the clock opened an EMPTY menu that stalled for several
# seconds before the buttons appeared; it happened even without restarting
# clash, and only a restart of clash made the first click slow again.
# Root cause: clash-verge-rev embeds the whole subscription node list once
# per proxy group into its dbusmenu tray menu (~3686 items = 18 groups x
# ~204 nodes for a mid-size subscription) and re-assigns a fresh id space on
# every menu rebuild; the appindicator extension defers LayoutUpdated
# signals received while the menu is closed (dbusMenu.js `_onSignal`), then
# performs the full 3686-item destroy+rebuild synchronously on the next
# click: measured ~413ms main-thread slice unpacking the layout + 1.7MB
# GetGroupProperties reply + thousands of St widgets created in a single
# PRIORITY_LOW idle => 5-6s shell freeze, menu visible empty until widgets
# and labels land. Re-opens stay fast until clash rebuilds its menu again
# (restart, subscription/config change, or any tray action such as
# "open window").
# Workaround (landed 2026-10-04, lives in clash-verge's own runtime config,
# NOT managed by this module): Clash Verge GUI -> Settings -> Layout
# Settings -> "Proxy Groups Display Mode" -> Disable, i.e.
# `tray_proxy_groups_display_mode: disable` in verge.yaml. The tray menu
# shrinks to ~14 items and the stall disappears.
# Upstream issues (bodies verified 2026-10-04):
#   * clash-verge-rev PR #5946 (merged, milestone 2.4.5/2.5.0) - added the
#     disable switch; author measured ~30s whole-desktop freeze on tray open
#     with 42 groups x 316 items and states the menu update cannot be made
#     fast: https://github.com/clash-verge-rev/clash-verge-rev/pull/5946
#   * clash-verge-rev issue #7779 - large subscription freezes GNOME Shell
#     through ubuntu-appindicators dbusMenu.js (GC/destroy storm, stacks
#     match the same destroy path); same tray_proxy_groups_display_mode
#     workaround: https://github.com/clash-verge-rev/clash-verge-rev/issues/7779
#   * clash-verge-rev issue #8076 - Ubuntu 24.04: tray click does not fully
#     expand the menu and the next click stalls; upstream contributor
#     suggests disabling tray proxy groups:
#     https://github.com/clash-verge-rev/clash-verge-rev/issues/8076
#   * No issue on ubuntu/gnome-shell-extension-appindicator matches this
#     deferred-LayoutUpdated click stall exactly (searched 2026-10-04);
#     closest relatives: #548 introduced the defer-while-closed branch that
#     causes it, #616 reports a dbusMenu.js GC callback storm with the same
#     stacks as clash-verge-rev #7779.
{
  programs.clash-verge = {
    enable = true;
    package = pkgs-master.clash-verge-rev;
    autoStart = false;
    serviceMode = true;
    tunMode = false;
  };
}
