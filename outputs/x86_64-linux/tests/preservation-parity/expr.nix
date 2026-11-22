# The preservation modules are kept byte-identical across the three hosts on
# purpose (see hosts/wsl-work/preservation.nix); this test fails the eval when
# one host's copy drifts, which is the git-native replacement for symlinks or
# hardlinks (git materialises one file per path on checkout).
{
  lib,
  mylib,
}:
let
  hosts = [
    "idols-ai"
    "wsl-work"
    "wsl-y9000p2025"
  ];
  files = [
    "preservation.nix"
    "preservation-downstream.nix"
  ];
  hash =
    host: file:
    builtins.hashString "sha256" (builtins.readFile (mylib.relativeToRoot "hosts/${host}/${file}"));
  identical = file: lib.all (host: hash host file == hash "idols-ai" file) hosts;
in
builtins.listToAttrs (
  map (file: {
    name = file;
    value = identical file;
  }) files
)
