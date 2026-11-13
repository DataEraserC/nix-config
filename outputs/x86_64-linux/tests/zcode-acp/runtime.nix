{
  config,
  pkgs,
}:
let
  fakeZcodeCli = pkgs.writeShellScriptBin "zcode-cli" ''
    exit 0
  '';
  fakeZcodeAcp = pkgs.writeShellScriptBin "zcode-acp" ''
    exit 0
  '';
  fakeZcodeAcpResume = pkgs.writeShellScriptBin "zcode-acp-resume" ''
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
        test "$1" = ${fakeZcodeAcp}/bin/zcode-acp
        ;;
      acp-resume-1)
        test "$#" -eq 2
        test "$1" = ${fakeZcodeAcpResume}/bin/zcode-acp-resume
        test "$2" = sess_test
        ;;
      cli-1)
        test "$#" -eq 1
        test "$1" = ${fakeZcodeCli}/bin/zcode-cli
        ;;
      cli-resume)
        test "$#" -eq 2
        test "$1" = ${fakeZcodeCli}/bin/zcode-cli
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
      fakeZcodeCli
      fakeZcodeAcp
      fakeZcodeAcpResume
      fakeBwrap
    ];
  }
  ''
    export HOME="$PWD/home"
    export MULTI_INSTANCE_ROOT="$PWD/state"
    export MULTI_INSTANCE_SPEC=${config.modules.multi-instance.specFile}
    export BWRAP_TRACE="$PWD/bwrap.trace"
    mkdir -p "$HOME"

    # The adapter's TTY dispatch makes one multi-instance argv serve both
    # sides: WebMux launches it in a PTY (Martty TUI) and over pipes (stdio).
    BWRAP_CASE=acp-1 ${pkgs.bash}/bin/bash ${launcher} zcode-acp 1
    BWRAP_CASE=acp-resume-1 ${pkgs.bash}/bin/bash ${launcher} zcode-acp-resume 1 sess_test
    BWRAP_CASE=cli-1 ${pkgs.bash}/bin/bash ${launcher} zcode-cli 1
    BWRAP_CASE=cli-resume ${pkgs.bash}/bin/bash ${launcher} zcode-cli 1 --resume

    expected=$(printf 'acp-1\nacp-resume-1\ncli-1\ncli-resume')
    test "$(cat "$BWRAP_TRACE")" = "$expected"

    # Every zcode form shares one state directory per instance, so a session
    # created on one side resumes on the other.
    test -d "$MULTI_INSTANCE_ROOT/zcode-cli/1/.zcode"
    test ! -e "$MULTI_INSTANCE_ROOT/zcode-acp"
    test ! -e "$MULTI_INSTANCE_ROOT/zcode-acp-resume"
    # The GUI app keeps its own state key; this test never creates it.
    test ! -e "$MULTI_INSTANCE_ROOT/zcode"
    touch "$out"
  ''
