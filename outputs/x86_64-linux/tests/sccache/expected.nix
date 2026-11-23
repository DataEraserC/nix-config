{
  module = {
    enabled = true;
    cacheSize = "32G";
    usesScopedPackage = true;
    uid = 952;
    gid = 952;
    serviceUser = "sccache";
    serviceGroup = "nixbld";
    socketPath = "/run/sccache/sccache.sock";
    socketExposed = true;
    permissionWatch = true;
    unixOnly = true;
  };

  torch = {
    marked = true;
    notOnBuildPath = true;
    cuda = true;
    c = false;
    cxx = false;
    upstreamNvccPathFix = true;
  };
}
