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
  imports = [
    nix-gaming.nixosModules.pipewireLowLatency
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

    # Expose DW-Proton to umu-run: umu ignores Steam's
    # STEAM_EXTRA_COMPAT_TOOLS_PATHS, and a store path baked into a generated
    # launcher goes stale on every dwproton-bin update. The nix-config-umu-game
    # skill and the run/exec scripts it generates read this first.
    environment.variables.UMU_PROTONPATH = "${pkgs.dwproton-bin.steamcompattool}";

    # GameScope: run a game in its own nested compositor and let it renice
    # itself for steadier frame pacing. GPU-specific PRIME render offload belongs
    # to the host, not here (see programs.gamescope.env in
    # hosts/idols-ai/hardware-nvidia.nix).
    # https://github.com/ValveSoftware/gamescope
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # see https://github.com/fufexan/nix-gaming/#pipewire-low-latency
    services.pipewire.lowLatency.enable = true;
    programs.steam.platformOptimizations.enable = true;

    # Optimise Linux system performance on demand
    # https://github.com/FeralInteractive/GameMode
    # https://wiki.archlinux.org/title/Gamemode
    #
    # Usage:
    #   1. For games/launchers which integrate GameMode support:
    #      https://github.com/FeralInteractive/GameMode#apps-with-gamemode-integration
    #      simply running the game will automatically activate GameMode.
    programs.gamemode.enable = true;

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
