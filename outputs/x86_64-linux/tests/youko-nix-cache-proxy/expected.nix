# Values adapted to the downstream fleet: upstream asserts its own machines'
# topology, and the upstream expr logic is kept verbatim while this expected
# file carries the downstream reality (see the review round, 2026-11-23).
{
  cacheLivesOnDataVolume = true;
  cachixProxyConfigured = false;
  cachixUpstream = "https://ryan4yin_cachix_org/";
  caddyVhostExists = true;
  directFallbacks = false;
  lanCacheFirst = false;
  nginxEnabled = true;
  nixosProxyConfigured = false;
  nixosUpstream = "https://cache_nixos_org/";
  numtideProxyConfigured = false;
  numtideUpstream = "https://cache_numtide_com/";
  upstreamServers = {
    cache_nixos_org = [
      "cache.nixos.org:443"
    ];
    cache_numtide_com = [
      "cache.numtide.com:443"
    ];
    mirrors_ustc_edu_cn = [
      "mirrors.ustc.edu.cn:443"
    ];
    ryan4yin_cachix_org = [
      "ryan4yin.cachix.org:443"
    ];
  };
  ustcProxyConfigured = false;
  ustcUpstream = "https://mirrors_ustc_edu_cn/nix-channels/store/";
}
