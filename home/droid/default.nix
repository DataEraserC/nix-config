{
  imports = [
    ./font.nix
    ./development.nix
    ./menu.nix
    ./dewm.nix
    ./browsers.nix
    ./system-tools.nix
    ./ENV_VAR.nix
    ./others.nix
    # nix-on-droid common
    ./virtualisation.nix
    ./x11_catppuccin.nix
    ./nix.nix
    # common
    # 提供 catppuccin home 模块，与 home/linux/tui.nix 的导入保持一致；
    # fork 自建的 droid 此前漏了它。
    ../base/core/theme.nix
    ../base/tui/custom
    ../base/tui/editors
    ../base/tui/dev-tools.nix
    ../base/tui/shell
    ./fhs.nix
    ../base/home.nix
  ];
}
