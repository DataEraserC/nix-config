{
  description = "Ryan Yin's nix configuration for both NixOS & macOS";

  ##################################################################################################################
  #
  # Want to know Nix in details? Looking for a beginner-friendly tutorial?
  # Check out https://github.com/ryan4yin/nixos-and-flakes-book !
  #
  ##################################################################################################################

  outputs = inputs: import ./outputs inputs;

  # This is the standard format for flake.nix. `inputs` are the dependencies of the flake,
  # Each item in `inputs` will be passed as a parameter to the `outputs` function after being pulled and built.
  inputs = {
    # There are many ways to reference flake inputs. The most widely used is github:owner/name/reference,
    # which represents the GitHub repository URL + branch/commit-id/tag.

    # Official NixOS package source, using nixos's unstable branch by default
    # Find git commit hash with build status here(3 jobs per day):
    # https://hydra.nixos.org/jobset/nixpkgs/unstable
    # update via nix flake update nixpkgs --override-input nixpkgs github:NixOS/nixpkgs/<commit-hash>
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Pinned to release tag v2.4.0 (not a branch); bump deliberately when needed.
    fcitx5-vinput = {
      url = "github:xifan2333/fcitx5-vinput/v2.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    # Kept for pinning a package that regressed in newer nixpkgs. Currently only
    # kubernetes-helm uses it (home/base/tui/container.nix); extend or drop this
    # input together with that consumer.
    nixpkgs-2505.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-latest.url = "github:nixos/nixpkgs/master";
    nixpkgs-unstable-yuzu.url = "github:nixos/nixpkgs?rev=6a59b7def496268fc32175183e4041d92586b00b";
    nixpkgs-unstable-etcher.url = "github:nixos/nixpkgs?rev=15cf1bacec81d3905d40b8005f88bb3ad8dc5a56";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # ryan4yin/nixpkgs fork for the `.agents/skills/nixpkgs-patched` workflow. It
    # currently carries no patches (see WORKAROUNDS.md), but `pkgs-patched` is
    # wired in outputs/default.nix so a temporary carry needs no flake edit.
    nixpkgs-patched.url = "github:ryan4yin/nixpkgs/nixos-unstable-patched";
    # get some latest packages from the master branch
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    # NixOS MicroVMs -- run the VMs directly on the hosts, replacing the former KubeVirt
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # for macos
    # nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/master";
      # url = "github:nix-community/home-manager/release-26.05";

      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs dependencies.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/catppuccin/nix
    # main carries the rust-overlay-style deprecation fix for its vscode
    # package (nodejs -> nodejs-slim).
    catppuccin = {
      url = "github:catppuccin/nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # lanzaboote's pinned rust-overlay still uses the deprecated
    # `stdenv.isLinux`/`stdenv.isDarwin`; follow a newer revision.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation = {
      url = "github:nix-community/preservation";
    };

    # Remote deployment via SSH. Pinned to the same v0.5.0 that nixpkgs ships
    # so the `colmenaHive` output we expose matches the CLI's schema.
    colmena = {
      url = "github:nix-community/colmena/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
      # Reuse the flake's own stable nixpkgs instead of colmena's pinned copy.
      inputs.stable.follows = "nixpkgs-stable";
    };

    # secrets management
    # Pinned to a release tag (not a branch) so `just up` cannot move it
    # silently; bump deliberately when a new release is needed.
    agenix = {
      url = "github:ryantm/agenix/0.18.0";
      # replaced with a type-safe reimplementation to get a better error message and less bugs.
      # url = "github:ryan4yin/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # Reuse the flake's own nix-darwin / home-manager instead of agenix's
      # pinned copies, collapsing duplicate lock nodes.
      inputs.darwin.follows = "nix-darwin";
      inputs.home-manager.follows = "home-manager";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # add git hooks to format nix code before commit
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned nixpkgs for Blender (5.2 LTS + CUDA/OptiX).  Keeping it on a fixed
    # rev stops `just up` from re-bumping this input and triggering a full
    # Blender/CUDA source rebuild; bump the rev deliberately when needed.
    nixpkgs-blender.url = "github:nixos/nixpkgs/4b8338e3113dc41bcf7695f56dc372107b7ff4c9";

    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI coding agents
    llm-agents.url = "github:numtide/llm-agents.nix";

    # DeepSeek Harness (dsh)
    deepseek-harness = {
      url = "github:moraxyc/deepseek-harness.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------- Gaming ---------------------

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aagl = {
      url = "github:ezKEa/aagl-gtk-on-nix/main";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # x86/x86_64 emulation on 16K-page ARM64 (Apple Silicon). FEX cannot run
    # natively with 16K pages, so this wraps FEX in a 4K-page muvm microVM and
    # exposes an `x86pkgs` set plus Steam/Wine launchers. Used by shoukei; see
    # hosts/12kingdoms-shoukei and WORKAROUNDS.md (WA-021).
    #
    # Pinned to our fork of rowanG077/nix-x86-on-aarch64 at the reviewed commit
    # 5d69793a. To update, fetch upstream into the fork, review the new commits,
    # then bump the rev here deliberately. Do not track the fork's default branch:
    # a GitHub "Sync fork" fast-forward would pull unreviewed changes.
    nix-x86-on-aarch64 = {
      url = "github:ryan4yin/nix-x86-on-aarch64/5d69793a1c8b31d724fccd9b6acaa33587c923b3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ########################  Some non-flake repositories  #########################################

    nu_scripts = {
      url = "github:ryan4yin/nu_scripts";
      flake = false;
    };

    # Global agent skills, linked into ~/.agents/skills by
    # home/base/tui/agents/skills.nix. The ryan4yin forks track main; a fork sync
    # pulls upstream changes, so review the lock diff before deploying it.
    mattpocock-skills = {
      url = "github:ryan4yin/mattpocock-skills";
      flake = false;
    };
    i-have-adhd = {
      url = "github:ryan4yin/i-have-adhd";
      flake = false;
    };
    # Third-party skills pinned to a tag or commit; bump deliberately.
    humanizer = {
      url = "github:blader/humanizer/v3.1.0";
      flake = false;
    };
    ponytail = {
      url = "github:DietrichGebert/ponytail/v5.1.0";
      flake = false;
    };

    ########################  My own repositories  #########################################

    # my private secrets, it's a private repository, you need to replace it with your own.
    # use ssh protocol to authenticate via ssh-agent/ssh-key, and shallow clone to save time
    mysecrets = {
      # url = "github:DataEraserC/nix-secrets";
      # url = "git+ssh://git@github.com/DataEraserC/nix-secrets.git?shallow=1";
      url = "git+file:////home/nixos/nix-config/secrets?shallow=1";
      flake = false;
    };

    # my-asahi-firmware = {
    #   url = "git+ssh://git@github.com/ryan4yin/asahi-firmware.git?shallow=1";
    #   flake = false;
    # };

    # my wallpapers
    wallpapers = {
      url = "github:ryan4yin/wallpapers";
      # url = "github:Program-Learning/wallpapers/dark_wallpapers";
      # url = "git+file:////home/nixos/Documents/code/wallpapers?shallow=1";
      flake = false;
    };

    # Personal NUR packages.
    nur-ryan4yin = {
      url = "github:ryan4yin/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Wayland <-> X11 clipboard sync daemon for xwayland-satellite (niri)
    pyclipsync = {
      url = "github:ryan4yin/pyclipsync/v0.1.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # terminal window manager / multiplexer; nixpkgs lags behind upstream,
    # so track the upstream flake.
    tuios = {
      url = "github:Gaurav-Gosain/tuios/v0.9.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # for waydroid
    nur-ataraxiasjel.url = "github:AtaraxiaSjel/nur";

    wpsFonts.url = "github:hypercrusher/wpsfonts";

    # for windows wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    # for nix-on-droid
    nixpkgs-nod.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable-nod.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager-nod = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-nod";
    };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nur-ryan4yin-nod = {
      url = "github:ryan4yin/nur-packages";
      # inputs.nixpkgs.follows = "nixpkgs-nod";
    };

    nur-DataEraserC-nod = {
      url = "github:DataEraserC/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin-urxvt = {
      url = "github:catppuccin/urxvt/ccd8eb763edd0a382b5e9bbfbd9697c4d4129edf";
      flake = false;
    };

    # AstroNvim is an aesthetic and feature-rich neovim config.
    astronvim-nod = {
      url = "github:AstroNvim/AstroNvim/v3.37.12";
      flake = false;
    };

    fakedroid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    suyu = {
      # url = "git+https://git.suyu.dev/suyu/nix-flake";
      url = "git+https://github.com/suyu-emu/nix-flake";
      # url = "github:Noodlez1232/suyu-flake";
    };

    # hyprwm
    hyprland = {
      type = "git";
      url = "https://github.com/hyprwm/Hyprland";
      submodules = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hypridle = {
      url = "github:hyprwm/hypridle";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      # inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
      inputs.systems.follows = "hyprland/systems";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins/e9457e08ca3ff16dc5a815be62baf9e18b539197";
      inputs.hyprland.follows = "hyprland";
    };

    hyprlock = {
      url = "github:hyprwm/hyprlock";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      # inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
      inputs.systems.follows = "hyprland/systems";
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      # inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.nixpkgs.follows = "hyprland/nixpkgs";
      inputs.systems.follows = "hyprland/systems";
    };

    Hyprspace = {
      url = "github:KZDKM/Hyprspace/a44d834af279f233a269d065d2e14fe4101d6f41";

      # Hyprspace uses latest Hyprland. We declare this to keep them in sync.
      inputs.hyprland.follows = "hyprland";
    };

    hycov = {
      url = "github:DreamMaoMao/hycov/05fb15703d07a372b14a3260a337de13d1c16b91";
      inputs.hyprland.follows = "hyprland";
    };

    hyprfocus = {
      url = "github:pyt0xic/hyprfocus/e44b956dd4b7507489219bd2b02a3886d547b7e2";
      inputs.hyprland.follows = "hyprland";
    };

    hyprland-easymotion = {
      url = "github:DreamMaoMao/hyprland-easymotion/a1a4969ddf68dc78be024a0fdf4ce1f8f6b9d74d";
      inputs.hyprland.follows = "hyprland";
    };

    firefox-nightly = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    browser-previews = {
      url = "github:nix-community/browser-previews";
      # url = "github:Apps-Used-By-Myself/browser-previews";
      # disable bcs this break some xdg-utils(?) like save file dialog but do not work
      inputs.nixpkgs.follows = "nixpkgs";
    };

    coder = {
      url = "github:coder/coder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ######################## dots_hyprland required  #########################################

    # DataEraserC-dots_hyprland = {
    #   url = "github:DataEraserC/dots-hyprland";
    #   # url = "git+file:////home/nixos/Documents/code/dots-hyprland?shallow=1";
    # };

    nixified-ai = {
      url = "github:nixified-ai/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixified-ai-old = {
      url = "github:nixified-ai/flake/2aeb76f52f72c7a242f20e9bc47cfaa2ed65915d";
    };

    nixified-ai-old-lock = {
      url = "github:Program-Learning/nixified-ai-flake/63339e4c8727578a0fe0f2c63865f60b6e800079";
      inputs.nixpkgs.follows = "nixified-ai-nixpkgs";
    };

    nixified-ai-nixpkgs.url = "github:nixos/nixpkgs/c757e9bd77b16ca2e03c89bf8bc9ecb28e0c06ad";

    #nix-melt = {
    #  url = "github:nix-community/nix-melt";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    LaphaeL-aicmd = {
      url = "github:DataEraserC/LaphaeL-aicmd";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    daeuniverse = {
      # url = "github:daeuniverse/flake.nix/6e2e7bd90cc95d9f668a613740497577ec1822c5";
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cpolar tunnel status query tool
    cpolar-status = {
      url = "github:Program-Learning/cpolar-status";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # oray smart plug control tool
    oray-tools = {
      url = "github:desktop-tools-which-may-be-useful/oray-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NUR package source

    nur.url = "github:nix-community/NUR";

    clash-nyanpasu = {
      url = "github:DataEraserC/nur-packages/142b102b895bfe9bedf23504eb30e73d81f0f130";
    };

    gradle2nix = {
      url = "github:tadfisher/gradle2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cargo2nix = {
      url = "github:cargo2nix/cargo2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    flake-utils.url = "github:numtide/flake-utils";

    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.flake-utils.follows = "flake-utils";
    };

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # appcast: cast an app's GUI into a native window on this desktop
    # (adb/scrcpy virtual display, system-browser app mode, webview plugins)
    appcast = {
      url = "github:AndroidAppsUsedByMyself/appcast";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-Moraxyc = {
      url = "github:Moraxyc/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-linyinfeng = {
      url = "github:linyinfeng/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-nykma = {
      url = "github:nykma/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-DataEraserC = {
      url = "github:DataEraserC/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.deepseek-harness.follows = "deepseek-harness";
    };

    # qq-bridge fork 源码（github 分支 master-downstream，flake=false）。
    # 改完 fork 仓库要先 push 到 GitHub，再 `nix flake update qq-bridge-fork`
    # 刷新 narHash 后构建/切换。
    qq-bridge-fork = {
      url = "github:DataEraserC/qq-bridge?ref=master-downstream";
      flake = false;
    };

    nur-DataEraserC-not-follow = {
      url = "github:DataEraserC/nur-packages";
    };

    winpodx = {
      url = "github:kernalix7/winpodx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # pve-nixos
    proxmox-nixos = {
      url = "github:SaumonNet/proxmox-nixos";
    };

    # noctalia-shell
    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell/v4.6.7";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    Snowpkgs = {
      url = "github:Daru-san/Snowpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    atl-nix = {
      url = "github:Daru-san/atl-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";

      # The main branch follows the "canary" channel of the Android SDK
      # repository. Use another android-nixpkgs branch to explicitly
      # track an SDK release channel.
      #
      # url = "github:tadfisher/android-nixpkgs/stable";
      # url = "github:tadfisher/android-nixpkgs/beta";
      # url = "github:tadfisher/android-nixpkgs/preview";
      # url = "github:tadfisher/android-nixpkgs/canary";

      # If you have nixpkgs as an input, this will replace the "nixpkgs" input
      # for the "android" flake.
      #
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    linyaps-flake = {
      url = "github:nix-community/linyaps-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # riscv64 SBCs
    nixos-licheepi4a.url = "github:ryan4yin/nixos-licheepi4a";
    # nixos-jh7110.url = "github:ryan4yin/nixos-jh7110";

    # aarch64 SBCs
    nixos-rk3588.url = "github:ryan4yin/nixos-rk3588";

    nix-jetbrains-plugins = {
      url = "github:nix-community/nix-jetbrains-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-remote-workaround = {
      url = "github:K900/vscode-remote-workaround";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dbx = {
      url = "github:t8y2/dbx";
      inputs.nixpkgs.follows = "nixpkgs"; # optional
    };
  };
}
