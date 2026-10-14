# Packages pinned in this tree that nixpkgs marks as insecure.
#
# Kept as a standalone module (instead of deleting it with the old shared
# desktop snippet) so home configs that still install them can evaluate:
# ventoy (home/linux/gui/base/misc.nix), IDEA (home/hosts/linux/jetbrains.nix;
# nixpkgs renamed pname idea-oss -> intellij-idea-oss), and cherry-studio's
# electron/pnpm build deps. Applying it repo-wide is harmless - the list only
# matters when those exact derivations are built. Drop an entry once nixpkgs
# stops marking that exact version insecure.
{ ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
    "electron-41.10.6"
    "ventoy-1.1.17"
    "intellij-idea-oss-2025.3.4"
    "intellij-idea-oss-with-plugins-2025.3.4"
    # build-time dependency of cherry-studio
    "pnpm-10.29.2"
  ];
}
