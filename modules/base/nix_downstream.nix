# Downstream substituter configuration, kept in a separate file so the upstream
# modules/base/nix.nix stays byte-identical. mkForce replaces the whole list:
# the preferred order is the CERNET mirror first, then our own and the community
# caches. The two NUR-cache URLs that modules/base/cache.nix contributes are
# restated here because a mkForce definition overrides that module's plain one.
{
  lib,
  nur-xddxdd,
  nur-DataEraserC,
  ...
}:
let
  # xddxdd's attic mirror (kept in sync with nur-xddxdd's helpers/meta.nix)
  attic = import "${nur-xddxdd}/helpers/meta.nix";
  # our own cachix (kept in sync with nur-DataEraserC's helpers/meta.nix)
  deraser = import "${nur-DataEraserC}/helpers/meta.nix";

  extra-substituters = [
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

    # nix-community's cache: other Cachix caches re-serve its store paths (they
    # keep nix-community's own signature rather than re-signing), so without
    # this every such path fell back to a slower mirror.
    "https://nix-community.cachix.org"

    # "https://cache.saumon.network/proxmox-nixos"
  ];

  extra-trusted-public-keys = [
    "catppuccin.cachix.org-1:noG/4HkbhJb+lUAdKrph6LaozJvAeEEZj4N732IysmU="
    # "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="

    "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
    "dataeraserc.cachix.org-1:t0lYPod3nkn0ijiOzjwT57MmBDeJnxVurvV8ZdPpIHo="
    "program-learning.cachix.org-1:Pfl2r+J5L9wJqpDnop6iQbrR3/Ts4AUyotu89INRlSU="
    "nykma.cachix.org-1:z04hZH9YnR1B2lpLperwiazdkaT5yczgOPa1p/NHqK4="

    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="

    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

    "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="

    "snowy-cache.cachix.org-1:okWl5IF/yzdZ+p/eRhDFvcanQo/y0ta80dvfdGgy28U="

    "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

    # "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM="
  ];
in
{
  nix.settings.substituters = lib.mkForce (
    [
      # cache mirror located in China: unified CERNET entry, redirects to the
      # optimal node per network line
      # ref: https://help.mirrors.cernet.edu.cn/nix-channels/
      "https://mirrors.cernet.edu.cn/nix-channels/store"

      # numtide's cache (niks3), which serves the prebuilt packages of the
      # numtide/llm-agents.nix flake input used for the AI agent CLIs.
      "https://cache.numtide.com"

      "https://nykma.cachix.org"
      "https://linyinfeng.cachix.org"
      "https://program-learning.cachix.org"
      "https://ai.cachix.org"

      attic.atticUrl
      deraser.cachixUrl
    ]
    ++ extra-substituters
  );

  nix.settings.trusted-public-keys = lib.mkForce (
    [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nykma.cachix.org-1:z04hZH9YnR1B2lpLperwiazdkaT5yczgOPa1p/NHqK4="
      "linyinfeng.cachix.org-1:sPYQXcNrnCf7Vr7T0YmjXz5dMZ7aOKG3EqLja0xr9MM="
      "program-learning.cachix.org-1:Pfl2r+J5L9wJqpDnop6iQbrR3/Ts4AUyotu89INRlSU="
      "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      attic.atticPublicKey
      deraser.cachixPublicKey
    ]
    ++ extra-trusted-public-keys
  );
}
