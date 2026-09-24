{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  # 桌面主机（含 fork 新增的 gnome/kde 变体）启用防火墙，服务器关闭
  name:
  name == "ai-niri"
  || name == "ai-gnome-wayland"
  || name == "ai-kde-wayland"
  || name == "shoukei-niri"
)
