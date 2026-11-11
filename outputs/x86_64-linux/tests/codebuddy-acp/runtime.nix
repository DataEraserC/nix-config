{
  config,
  pkgs,
}:
let
  fakeCodeBuddy = pkgs.writeShellScriptBin "codebuddy-acp" ''
    exit 0
  '';
  fakeCodeArts = pkgs.writeShellScriptBin "codearts" ''
    exit 0
  '';
  fakeTrae = pkgs.writeShellScriptBin "trae-cn" ''
    exit 0
  '';
  fakeBwrap = pkgs.writeShellScriptBin "bwrap" ''
    set -euo pipefail

    while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
      shift
    done
    test "$#" -ge 2
    test "$1" = --
    shift

    case "''${BWRAP_CASE:?BWRAP_CASE must name the expected invocation}" in
      canonical | legacy)
        test "$#" -eq 2
        test "$1" = ${fakeCodeBuddy}/bin/codebuddy-acp
        test "$2" = --acp
        ;;
      codearts | alias-default)
        test "$#" -eq 2
        test "$1" = ${fakeCodeArts}/bin/codearts
        test "$2" = --version
        ;;
      trae-cn)
        test "$#" -eq 3
        test "$1" = ${fakeTrae}/bin/trae-cn
        test "$2" = "--user-data-dir=$MULTI_INSTANCE_ROOT/trae-cn/profile/data"
        test "$3" = --inspect
        ;;
      *)
        exit 2
        ;;
    esac

    printf '%s\n' "$BWRAP_CASE" >> "$BWRAP_TRACE"
  '';
  launcher = ../../../../modules/nixos/base/custom/multi-instance/multi-instance.sh;
in
pkgs.runCommandLocal "codebuddy-acp-multi-instance-state-test"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      fakeCodeBuddy
      fakeCodeArts
      fakeTrae
      fakeBwrap
    ];
  }
  ''
    export HOME="$PWD/home"
    export MULTI_INSTANCE_ROOT="$PWD/state"
    export MULTI_INSTANCE_SPEC=${config.modules.multi-instance.specFile}
    export BWRAP_TRACE="$PWD/bwrap.trace"
    mkdir -p "$HOME"

    BWRAP_CASE=canonical ${pkgs.bash}/bin/bash ${launcher} codebuddy-acp 1 --acp
    BWRAP_CASE=legacy ${pkgs.bash}/bin/bash ${launcher} codebuddy legacy --acp
    BWRAP_CASE=codearts ${pkgs.bash}/bin/bash ${launcher} codearts default --version
    BWRAP_CASE=alias-default ${pkgs.bash}/bin/bash ${launcher} codearts-old compat --version
    BWRAP_CASE=trae-cn ${pkgs.bash}/bin/bash ${launcher} trae-cn profile --inspect

    expected=$(printf 'canonical\nlegacy\ncodearts\nalias-default\ntrae-cn')
    test "$(cat "$BWRAP_TRACE")" = "$expected"

    test -d "$MULTI_INSTANCE_ROOT/codebuddy/1/.codebuddy"
    test -d "$MULTI_INSTANCE_ROOT/codebuddy/1/.local/share/CodeBuddyExtension"
    test -d "$MULTI_INSTANCE_ROOT/codebuddy/legacy/.codebuddy"
    test -d "$MULTI_INSTANCE_ROOT/codebuddy/legacy/.local/share/CodeBuddyExtension"
    test ! -e "$MULTI_INSTANCE_ROOT/codebuddy-acp"
    test -d "$MULTI_INSTANCE_ROOT/codearts/default/.codeartsdoer"
    test -d "$MULTI_INSTANCE_ROOT/codearts/compat/.codeartsdoer"
    test ! -e "$MULTI_INSTANCE_ROOT/codearts-old"
    test -d "$MULTI_INSTANCE_ROOT/trae-cn/profile/.config/Trae CN"
    touch "$out"
  ''
