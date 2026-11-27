# ===============================================================================
#
# Office document toolchain for AI agents - read/write Excel / Word / PowerPoint
# and render documents to per-page PNG images for visual verification.
#
# Shared base (enable = true): LibreOffice headless (`soffice`), poppler
# (`pdftoppm`), ONE python3.withPackages environment (pandas + the packages the
# excel/word/ppt switches select) exposed as `office-python` / `office-python3`
# so it coexists with any other system/home python, and the `office-render`
# helper (office-render.sh next to this file):
#
#   office-render <file> [outdir] [dpi]   # xlsx/docx/pptx/... -> PDF -> PNG images
#
# Fonts are deliberately NOT preset: pick `fonts` to match your documents'
# languages and referenced fonts, otherwise CJK glyphs render as boxes or get
# substituted with different metrics (see the option's example).
#
# Check (after switch)
#   soffice --version
#   pdftoppm -v
#   office-python -c "import openpyxl, docx, pptx, pandas"
#   fc-list :lang=zh | head
#   office-render test.xlsx
# ===============================================================================
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.office-tools;
  anyFormat = cfg.excel || cfg.word || cfg.ppt;

  # `libreoffice-fresh` evaluates to the same 26.8.0.3 derivation as `libreoffice`
  # in the locked nixpkgs but warns that upstream changed its versioning and to
  # use `libreoffice` instead; the home GUI profile (home/linux/gui/custom/
  # custom.nix) already installs `libreoffice`, so use it here too.
  libreoffice = pkgs.libreoffice;

  # Locked nixpkgs (nixos-unstable 26.11, rev 1c872b8c508b) spells the attr
  # `poppler-utils` (`poppler_utils` is only a compatibility alias).
  poppler = pkgs.poppler-utils;

  # Exactly ONE Python environment: merge the per-format packages into a single
  # list and call python3.withPackages once. markitdown 0.1.8 exists in the
  # locked nixpkgs (verified with nix eval); it pulls its own converter extras.
  #
  # Coexistence policy: this env is NOT added to environment.systemPackages
  # directly - it would collide on bin/python{,3} with the bare python313 in
  # modules/nixos/base/packages.nix (and fight Home Manager's per-user env on
  # PATH). Whoever declares python/python3 keeps them untouched; this module
  # exposes its env ONLY through the uniquely named office-python entry points
  # below, so both interpreters coexist regardless of profile order. With no
  # other python declared anywhere, office-python still works the same way.
  pythonEnv = pkgs.python3.withPackages (
    ps:
    [ ps.pandas ]
    ++ lib.optionals cfg.excel [
      ps.openpyxl
      ps.xlsxwriter
    ]
    ++ lib.optionals cfg.word [
      ps.python-docx
      ps.lxml
    ]
    ++ lib.optionals cfg.ppt [
      ps.python-pptx
      ps.pillow
    ]
    ++ lib.optional anyFormat ps.markitdown
  );

  # Unique names only (office-python / office-python3): no bin/python* is
  # created, so nothing here can shadow or collide with another profile's
  # interpreter. Symlinks (not wrappers) keep argv[0] semantics and venv
  # creation (`office-python -m venv`) working against the real env.
  officePython = pkgs.runCommand "office-python" { } ''
    mkdir -p $out/bin
    ln -s ${pythonEnv}/bin/python3 $out/bin/office-python
    ln -s ${pythonEnv}/bin/python3 $out/bin/office-python3
  '';

  # office-render <file> [outdir] [dpi]: headless soffice -> PDF -> pdftoppm.
  # The script body lives in office-render.sh (plain shell, no Nix string
  # interpolation - runtime values are script arguments). writeShellApplication
  # adds the shebang, `set -euo pipefail`, a shellcheck pass and runtimeInputs
  # on PATH.
  officeRender = pkgs.writeShellApplication {
    name = "office-render";
    runtimeInputs = [
      libreoffice
      poppler
      pkgs.coreutils
    ];
    text = builtins.readFile ./office-render.sh;
  };
in
{
  options.modules.office-tools = {
    enable = lib.mkEnableOption "AI office document toolchain (render & verify)";
    excel = lib.mkEnableOption "Excel (.xlsx) tooling";
    word = lib.mkEnableOption "Word (.docx) tooling";
    ppt = lib.mkEnableOption "PowerPoint (.pptx) tooling";

    fonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Fonts made available to LibreOffice for rendering.
        Not preset: choose fonts matching your documents' languages and
        the fonts they reference, otherwise glyphs may render as boxes
        or be substituted with different metrics.
      '';
      example = lib.literalExpression ''
        with pkgs; [
          noto-fonts-cjk-sans    # Chinese / Japanese / Korean
          noto-fonts-cjk-serif
          liberation_ttf         # metric-compatible with Arial / Times New Roman / Courier New
          carlito                # metric-compatible with Calibri
          caladea                # metric-compatible with Cambria
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings =
      lib.optional (cfg.fonts == [ ])
        "modules.office-tools: no fonts configured; CJK and other glyphs may render as boxes. Set modules.office-tools.fonts (see the option's example)."
      ++
        lib.optional (!anyFormat)
          "modules.office-tools: enabled but none of excel/word/ppt is on; installing only the common base (LibreOffice, poppler, pandas, office-render).";

    environment.systemPackages = [
      libreoffice
      poppler
      # Only the uniquely named entry points enter the profile; pythonEnv
      # itself stays out so bin/python{,3} is left to whoever declares it.
      officePython
      officeRender
    ]
    # word: docx <-> markdown/PDF conversions beyond python-docx.
    ++ lib.optional cfg.word pkgs.pandoc
    # JS-side document generation only when a format that may use it is on.
    # The npm libraries `docx` / `pptxgenjs` are intentionally NOT installed via
    # the deprecated nodePackages: add them per project with `npm install`, or
    # package them properly with buildNpmPackage.
    ++ lib.optional (cfg.word || cfg.ppt) pkgs.nodejs;

    fonts = lib.mkIf (cfg.fonts != [ ]) {
      packages = cfg.fonts;
      fontconfig.enable = true;
    };
  };
}
