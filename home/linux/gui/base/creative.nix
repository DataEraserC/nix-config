{ pkgs, ... }:
{
  # Downstream runs none of the nixpaks creative apps; what we actually use
  # lives in creative_downstream.nix. Entries stay as comments so upstream
  # edits to this list merge cleanly.
  home.packages = with pkgs; [
    # creative
    # nixpaks.krita # digital painting                # downstream: not used
    # nixpaks.musescore # music notation              # downstream: not used
    # nixpaks.orca-slicer # 3d printer slicer app     # downstream: no 3d printer
    # nixpaks.bambu-studio # bambu 3d printer slicer app # downstream: no 3d printer
    # nixpaks.blender # 3d modeling                   # downstream: not used
    # nixpaks.obs-studio # screen recording/streaming # downstream: runs the
    #   plugin-equipped programs.obs-studio module in creative_downstream.nix
  ];
}
