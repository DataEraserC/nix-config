# The downstream gaming stack, kept as its own opt-in module so the upstream
# modules/nixos/desktop/gaming.nix can stay byte-identical (upstream sandboxes
# Steam in a nixpak and reimplements the low-latency/sysctl work natively; we
# run plain Steam and take them from nix-gaming instead).
{
  pkgs,
  nix-gaming,
  aagl,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.gaming-stack;
in
{
  options.modules.gaming-stack = {
    enable = mkEnableOption "the downstream gaming stack (plain Steam, nix-gaming, anime-game launchers)";
  };

  # Unconditional imports (they were unconditional in the pre-split gaming.nix
  # too): the imported modules carry their own enable options, and gating via
  # `config` here would recurse (config-in-imports).
  #
  # platformOptimizations is imported only for its `programs.steam.
  # platformOptimizations` option declaration; it stays DISABLED because its
  # sysctls duplicate upstream's gaming.nix ones, and boot.kernel.sysctl
  # treats repeat definitions as unique-value conflicts. pipewireLowLatency is
  # likewise not imported: upstream's gaming.nix ships the identical
  # 99-lowlatency PipeWire config natively, and a second import would append a
  # duplicate libpipewire-module-rt entry.
  imports = [
    nix-gaming.nixosModules.platformOptimizations

    # run anime games on Linux
    aagl.nixosModules.default
  ];

  config = mkIf cfg.enable {
    # Games installed by Steam works fine on NixOS, no other configuration needed.
    # https://github.com/NixOS/nixpkgs/blob/master/doc/packages/steam.section.md
    programs.steam = {
      # Some location that should be persistent:
      #   ~/.local/share/Steam - The default Steam install location
      #   ~/.local/share/Steam/steamapps/common - The default Game install location
      #   ~/.steam/root        - A symlink to ~/.local/share/Steam
      #   ~/.steam             - Some Symlinks & user info
      enable = true;
      package = pkgs.steam;
      # https://github.com/Winetricks/winetricks
      # Whether to enable protontricks, a simple wrapper for running Winetricks commands for Proton-enabled games.
      protontricks.enable = true;
      # Whether to enable Load the extest library into Steam, to translate X11 input events to uinput events (e.g. for using Steam Input on Wayland).
      extest.enable = true;
      fontPackages = [
        pkgs.wqy_zenhei # Need by steam for Chinese
      ];
      # DW-Proton (Dawn Winery's Proton fork) carries the anti-cheat and game
      # patches that mainline Proton/GE-Proton lack, so it is what runs the anime
      # gacha games (Wuthering Waves, Honkai: Star Rail, Arknights: Endfield, ...);
      # GE-Proton is the general fallback. Both appear as compatibility tools in
      # each game's Properties -> Compatibility.
      # https://dawn.wine/dawn-winery/dwproton
      extraCompatPackages = [
        pkgs.dwproton-bin
        pkgs.proton-ge-bin
      ];
    };

    # low-latency PipeWire comes from upstream's gaming.nix native
    # 99-lowlatency config (see above); nix-gaming's pipewireLowLatency import
    # is deliberately omitted to avoid a duplicate module-rt entry.
    # programs.steam.platformOptimizations stays off: the sysctls it would set
    # are already carried by the upstream gaming module (identical values, but
    # boot.kernel.sysctl rejects duplicate definitions).

    # run anime games on Linux
    # https://github.com/an-anime-team/
    networking.mihoyo-telemetry.block = true;
    environment.systemPackages =
      with aagl.packages."x86_64-linux";
      [
        # anime-game-launcher # Genshin: Impact
        # honkers-railway-launcher # Honkai: Star Rail
        # sleepy-launcher # Zenless Zon Zero
      ]
      ++
        # Mayuri Spec
        (with pkgs; [
          nix-gaming.packages.${pkgs.system}.osu-lazer-bin
          # nix-gaming.packages.${pkgs.system}.osu-stable
          # prismlauncher # A free, open source launcher for Minecraft
          hmcl # MineCraft Launcher
          # minecraft # Official MineCraft Launcher
          # prismlauncher

          #mindustry-wayland
          #mindustry-server
        ]);
  };
}
