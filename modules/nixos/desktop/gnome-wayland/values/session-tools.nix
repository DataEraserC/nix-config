# GNOME session features, mirroring niri's values/session-tools.nix:
# - wf-recorder: virtual camera / virtual mic (module lives in base/custom/wf-recorder.nix),
#   registers /dev/video9 (v4l2loopback) + snd-aloop and installs the wf-screenshare helpers.
{ ... }:
{
  features.wf-recorder.enable = true;
}
