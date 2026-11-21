{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    # 桌面主机（含 fork 新增的 gnome/kde 变体）用 "no" + X11，服务器保持默认
    isDesktop =
      name == "ai-niri"
      || name == "ai-gnome-wayland"
      || name == "ai-kde-wayland"
      || name == "shoukei-niri";
  in
  {
    X11Forwarding = isDesktop;
    PermitRootLogin = if isDesktop then "no" else "prohibit-password";
  }
)
