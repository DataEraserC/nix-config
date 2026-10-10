{
  pkgs,
  config,
  ...
}:
let
  extra-substituters = [
    "https://cache.numtide.com"
    "https://catppuccin.cachix.org"
    # "https://nix-gaming.cachix.org"
    "https://nixpkgs-wayland.cachix.org"
    "https://install.determinate.systems"

    # Add by Mayuri
    "https://ezkea.cachix.org"
    "https://dataeraserc.cachix.org"
    "https://program-learning.cachix.org"
    "https://nykma.cachix.org"

    # comfyui-nix cache
    "https://comfyui.cachix.org"

    # "https://cache.garnix.io"

    "https://anyrun.cachix.org"

    "https://snowy-cache.cachix.org"

    # deepseek-harness-nix cache
    "https://deepseek-harness-nix.cachix.org"

    # "https://cache.saumon.network/proxmox-nixos"
  ];
  extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    # "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="

    "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    "dataeraserc.cachix.org-1:t0lYPod3nkn0ijiOzjwT57MmBDeJnxVurvV8ZdPpIHo="
    "program-learning.cachix.org-1:Pfl2r+J5L9wJqpDnop6iQbrR3/Ts4AUyotu89INRlSU="
    "nykma.cachix.org-1:z04hZH9YnR1B2lpLperwiazdkaT5yczgOPa1p/NHqK4="

    # comfyui-nix cache
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="

    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

    "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="

    "snowy-cache.cachix.org-1:okWl5IF/yzdZ+p/eRhDFvcanQo/y0ta80dvfdGgy28U="

    # deepseek-harness-nix cache
    "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="

    # "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM="
  ];
in
{
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
      # "ca-derivations"
    ];

    # NOTE: the normal user is deliberately NOT a trusted-user. That would
    # grant the right to inject arbitrary substituters (via `nixConfig` in a
    # flake, or `--option substituters ...`), which is a known root-equivalent
    # vector through the daemon. Every substituter we want is instead listed in
    # the system substituters below, which the daemon applies for every user.

    # WARNING: `substituters` + `trusted-public-keys` are a security boundary,
    # not a convenience list. Nix downloads prebuilt store paths from a
    # substituter, and a trusted key means "trust anything signed by it" —
    # together they let a cache inject arbitrary store paths into your system,
    # which are then run as root at activation. Only add caches you fully trust.
    # The official https://cache.nixos.org is always trusted and is appended
    # automatically, so it does not need to be listed here.
    substituters = [
      # cache mirror located in China
      # unified entry of China education network mirrors(CERNET), redirects to the optimal node per network line
      # ref: https://help.mirrors.cernet.edu.cn/nix-channels/
      "https://mirrors.cernet.edu.cn/nix-channels/store"
      # alternatives
      # status: https://mirrors.ustc.edu.cn/status/
      # "https://mirrors.ustc.edu.cn/nix-channels/store"
      # status: https://mirror.sjtu.edu.cn/
      # "https://mirror.sjtu.edu.cn/nix-channels/store"
      # "https://mirrors.sustech.edu.cn/nix-channels/store"
      # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"

      # numtide's cache (niks3), which serves the prebuilt packages of the
      # numtide/llm-agents.nix flake input used for the AI agent CLIs.
      "https://cache.numtide.com"
      # my own cache server, currently not used.
      # "https://ryan4yin.cachix.org"

      "https://nykma.cachix.org"
      "https://linyinfeng.cachix.org"
      "https://program-learning.cachix.org"
      "https://ai.cachix.org"

      # "https://cache.garnix.io"
    ]
    ++ extra-substituters;

    # WARNING: every key here trusts *everything* that key signs. Add one only
    # for a cache you trust as much as the official one — a careless key hands
    # a third party the ability to ship you arbitrary store paths.
    trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "ryan4yin.cachix.org-1:Gbk27ZU5AYpGS9i3ssoLlwdvMIh0NxG0w8it/cv9kbU="
      "nykma.cachix.org-1:z04hZH9YnR1B2lpLperwiazdkaT5yczgOPa1p/NHqK4="
      "linyinfeng.cachix.org-1:sPYQXcNrnCf7Vr7T0YmjXz5dMZ7aOKG3EqLja0xr9MM="
      "program-learning.cachix.org-1:Pfl2r+J5L9wJqpDnop6iQbrR3/Ts4AUyotu89INRlSU="
      "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ]
    ++ extra-trusted-public-keys;
    builders-use-substitutes = true;
  };
}
