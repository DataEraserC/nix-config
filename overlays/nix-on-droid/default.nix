{
  lib,
  feat ? { },
  ...
}@args:
# execute and import all overlay files in the current directory with the given args
# Included by every host through overlays/default.nix. On NixOS hosts the
# droid-specific overlays below are skipped (they break glibc-only package
# sets); the `feat."nix-on-droid"` flag that lib/nixOnDroidConfiguration.nix
# sets selects them. Nothing is logged on either branch: an eval-time warn
# here would print on every host evaluation.
if feat."nix-on-droid" or false then
  (lib.concatMap
    (
      f:
      let
        overlay = import (./. + "/${f}") args;
      in
      if lib.isList overlay then overlay else [ overlay ]
    ) # execute and import the overlay file

    (
      builtins.filter # find all overlay files in the current directory

        (
          f:
          f != "default.nix" # ignore default.nix
          && f != "README.md" # ignore README.md
        )
        (builtins.attrNames (builtins.readDir ./.))
    )
  )
else
  [ ]
