# Values adapted to the aarch64 fleet: the shared expr asserts every host in
# outputs.nixosConfigurations, and the values below are the aarch64 hosts'
# downstream reality (akane/shoukei-niri run the exporters with the LAN bind).
{

  akane = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
  shoukei-niri = {
    exportersBoundToLan = true;
    generatedRestrictionsBeforeTrust = true;
    ipv4Restricted = true;
    ipv6RestrictedBeforeTrust = true;
    lanRetained = true;
    tailnetRetained = true;
  };
}
