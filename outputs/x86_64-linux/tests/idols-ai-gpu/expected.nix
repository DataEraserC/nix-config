{
  loadsVirtualDisplay = true;
  createsVirtualDisplay = true;
  niriUsesIntelRenderer = true;
  # fork 给登录用户 nixos 加了 input 组（bongocat 需要），故此处为 true
  sunshineUserHasInputAccess = true;
  sunshineHasSysAdmin = false;
  sunshineUsesWlrCapture = "wlr";
  sunshineStartsAfterNiri = true;
  sunshineWaitsForNiriOutput = true;
  gnomeSunshineDoesNotStartAfterNiri = true;
  gnomeSunshineDoesNotWaitForNiriOutput = true;
}
