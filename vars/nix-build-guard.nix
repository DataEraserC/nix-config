# Shared guard values for Nix builds on the 30.7G RAM / 8G swap AI workstation.
# MemoryHigh throttles the daemon first; MemoryMax confines the hard limit to
# the nix-daemon cgroup instead of letting the kernel global OOM killer pick a
# desktop process. The client values cover `nix build`'s eval/coordinator
# process, which is not in the daemon cgroup.
{
  daemonMemoryHigh = "18G"; # ~59% of physical RAM
  daemonMemoryMax = "23G"; # ~75% of physical RAM
  clientMemoryMax = "12G"; # eval/coordinator only; builders live in the daemon
  clientMemorySwapMax = "8G";
  maxJobs = 4;
  cores = 2;
}
