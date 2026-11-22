{
  # Upstream (9fbed400) additionally asserts its RTX-4090 VR stack here:
  #   sunshinePinsNoAdapter / wivrn* / adbStatePreserved
  # This fork does not run that stack - the y9000p2025 encodes on the Intel
  # iGPU (sunshinePinsAdapter instead of PinsNoAdapter) and carries no
  # wivrn/adb setup - so those assertions are dropped, not maintained.
  loadsVirtualDisplay = true;
  createsVirtualDisplay = true;
  # niriUsesIntelRenderer = true was dropped with the renderer-pinning debug
  # block in niri-hardware.kdl (removed in the upstream-verbatim rebuild; niri
  # picks its render device on its own again).
  niriUsesIntelRenderer = false;
  sunshineUserHasInputAccess = false;
  sunshineHasSysAdmin = false;
  sunshineUsesWlrCapture = "wlr";
  sunshineStartsAfterNiri = true;
  sunshineWaitsForNiriOutput = true;
  gnomeSunshineDoesNotStartAfterNiri = true;
  gnomeSunshineDoesNotWaitForNiriOutput = true;
}
