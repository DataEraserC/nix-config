# Values adapted to the downstream fleet: upstream asserts its own machines'
# topology, and the upstream expr logic is kept verbatim while this expected
# file carries the downstream reality (see the review round, 2026-11-23).
{
  aquamarineConfigured = {
    ai-niri = false;
    shoryu = true;
    shushou = true;
    youko = true;
  };
  builderSystems = {
    ai-niri = [ ];
    shoryu = [
      [
        "x86_64-linux"
      ]
    ];
    shushou = [
      [
        "x86_64-linux"
      ]
    ];
    youko = [
      [
        "x86_64-linux"
      ]
    ];
  };
  distributedBuilds = {
    ai-niri = false;
    shoryu = true;
    shushou = true;
    youko = true;
  };
}
