{
  inputs,
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-gnome-wayland.config;
  unit = cfg.systemd.services.sccache;

  pkgs-cuda = import inputs.nixpkgs {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "12.0" ];
    };
    overlays = [ (import ../../../pkgs-cuda/torch-sccache-overlay.nix { inherit lib; }) ];
  };
  torch = pkgs-cuda.python314Packages.torch;
  hasLauncher = name: lib.any (lib.hasPrefix "-D${name}:STRING=") torch.cmakeFlags;
in
{
  module = {
    enabled = cfg.modules.sccache.enable;
    cacheSize = cfg.modules.sccache.cacheSize;
    usesScopedPackage = toString cfg.modules.sccache.package == toString torch.sccachePackage;
    uid = cfg.users.users.sccache.uid;
    gid = cfg.users.groups.sccache.gid;
    serviceUser = unit.serviceConfig.User;
    serviceGroup = unit.serviceConfig.Group;
    socketPath = unit.environment.SCCACHE_SERVER_UDS;
    socketExposed = builtins.elem "/run/sccache?" (cfg.nix.settings.extra-sandbox-paths or [ ]);
    permissionWatch =
      cfg.systemd.paths.sccache-socket-permissions.pathConfig.PathChanged == "/run/sccache";
    unixOnly = unit.serviceConfig.RestrictAddressFamilies == [ "AF_UNIX" ];
  };

  torch = {
    marked = torch.sccacheCudaEnabled;
    notOnBuildPath = lib.all (input: lib.getName input != "sccache") torch.nativeBuildInputs;
    cuda = hasLauncher "CMAKE_CUDA_COMPILER_LAUNCHER";
    c = hasLauncher "CMAKE_C_COMPILER_LAUNCHER";
    cxx = hasLauncher "CMAKE_CXX_COMPILER_LAUNCHER";
    upstreamNvccPathFix = lib.any (
      patch: lib.hasInfix "sccache-nvcc-inherited-path.patch" (baseNameOf patch)
    ) torch.sccachePackage.patches;
  };
}
