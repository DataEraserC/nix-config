# Values adapted to the downstream fleet: upstream asserts its own machines'
# topology, and the upstream expr logic is kept verbatim while this expected
# file carries the downstream reality (see the review round, 2026-11-23).
{
  desktopBatteryReporting = true;
  desktopRaplDisabled = true;
  governors = {
    ai-niri = "powersave";
    aquamarine = "powersave";
    shoryu = "powersave";
    shushou = "powersave";
    youko = "powersave";
  };
  guestsHaveNoCpuPolicy = false;
  guestsHaveNoRapl = true;
  noEeeWorkaround = true;
  noFrequencyCaps = true;
  noTuned = true;
  serverRaplEnabled = {
    aquamarine = true;
    shoryu = true;
    shushou = true;
    youko = true;
  };
  serverRaplReaderOnly = true;
}
