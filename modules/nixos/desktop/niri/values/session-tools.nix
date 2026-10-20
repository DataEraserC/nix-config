# niri-only session features, split out of the old desktop/custom/custom.nix:
# - wshowkeys: on-screen keybinding indicator for niri's key bindings.
# - wf-recorder: screen recorder (module lives in base/custom/desktop/wf-recorder.nix).
{ ... }:
{
  programs.wshowkeys.enable = true;
  features.wf-recorder.enable = true;
}
