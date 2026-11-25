{ ... }:
{
  fsType = "btrfs";
  retentionPeriod = 7;

  recursionUsesChild = true;
  recursionReusesArgument = false;
  createBeforeSweep = true;
  sweepKeepsOldRootsDir = true;
  sweepIsLoud = true;
  rotationIsAtomic = true;
}
