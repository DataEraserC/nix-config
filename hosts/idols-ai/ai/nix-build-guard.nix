# Downstream host module: confine Nix builds to a cgroup budget so a runaway
# build does not trigger the kernel global OOM killer and take an Electron
# renderer with it. Values and rationale live in vars/nix-build-guard.nix.
{
  modules.nix-build-guard.enable = true;
}
