# Values adapted to the downstream fleet: upstream asserts its own machines'
# topology, and the upstream expr logic is kept verbatim while this expected
# file carries the downstream reality (see the review round, 2026-11-23).
{
  ai-gnome-wayland = {
    exportersBoundToLan = false;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  ai-kde-wayland = {
    exportersBoundToLan = false;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  ai-niri = {
    exportersBoundToLan = false;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  aquamarine = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-master-1 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-master-2 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-master-3 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-worker-1 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-worker-2 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  k3s-test-1-worker-3 = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  kana = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  ruby = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  shoryu = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  shushou = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  youko = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
}
