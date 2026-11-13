{
  config,
  pkgs,
}:
let
  fakeZcode = pkgs.writeShellScriptBin "zcode" ''
    exit 0
  '';
  fakeZcodeAcpServer = pkgs.writeShellScriptBin "zcode-acp-server" ''
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
      acp-1)
        test "$#" -eq 1
        test "$1" = ${fakeZcodeAcpServer}/bin/zcode-acp-server
        ;;
      cli-1)
        test "$#" -eq 1
        test "$1" = ${fakeZcode}/bin/zcode
        ;;
      cli-resume)
        test "$#" -eq 2
        test "$1" = ${fakeZcode}/bin/zcode
        test "$2" = --resume
        ;;
      *)
        exit 2
        ;;
    esac

    printf '%s\n' "$BWRAP_CASE" >> "$BWRAP_TRACE"
  '';
  launcher = ../../../../modules/nixos/base/custom/multi-instance/multi-instance.sh;
in
pkgs.runCommandLocal "zcode-acp-multi-instance-state-test"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      fakeZcode
      fakeZcodeAcpServer
      fakeBwrap
    ];
  }
  ''
    export HOME="$PWD/home"
    export MULTI_INSTANCE_ROOT="$PWD/state"
    export MULTI_INSTANCE_SPEC=${config.modules.multi-instance.specFile}
    export BWRAP_TRACE="$PWD/bwrap.trace"
    mkdir -p "$HOME"

    BWRAP_CASE=acp-1 ${pkgs.bash}/bin/bash ${launcher} zcode-acp 1
    BWRAP_CASE=cli-1 ${pkgs.bash}/bin/bash ${launcher} zcode-cli 1
    BWRAP_CASE=cli-resume ${pkgs.bash}/bin/bash ${launcher} zcode-cli 1 --resume

    expected=$(printf 'acp-1\ncli-1\ncli-resume')
    test "$(cat "$BWRAP_TRACE")" = "$expected"

    # The ACP and TUI forms share one state directory per instance, so a
    # session created through the bridge can be resumed in the TUI.
    test -d "$MULTI_INSTANCE_ROOT/zcode-cli/1/.zcode"
    test ! -e "$MULTI_INSTANCE_ROOT/zcode-acp"
    # The GUI app keeps its own state key; this test never creates it.
    test ! -e "$MULTI_INSTANCE_ROOT/zcode"
    touch "$out"
  ''
