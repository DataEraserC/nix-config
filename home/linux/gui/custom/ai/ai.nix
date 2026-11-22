{
  pkgs,
  pkgs-cuda,
  pkgs-latest,
  nixified-ai,
  nixified-ai-old,
  comfyui-nix,
  ...
}:
{
  home.packages = [
    # nixified-ai.packages.${pkgs.system}.comfyui-nvidia
    # nixified-ai-old.packages.${pkgs.system}.invokeai-nvidia
    # nixified-ai-old.packages.${pkgs.system}.textgen-nvidia

    # comfyui-nix packages
    # comfyui-nix.comfy-ui        # CPU / Apple Silicon
    # comfyui-nix.packages.${pkgs.system}.cuda   # CUDA (Linux/NVIDIA)
    # comfyui-nix.packages.${pkgs.system}.rocm   # ROCm (Linux/AMD)
    # comfyui-nix.packages.${pkgs.system}.xpu    # Intel XPU

    # nixpkgs' comfyui packaging no longer takes `withManager`; the manager
    # ships in the default build.
    pkgs-cuda.comfyui
  ];
}
