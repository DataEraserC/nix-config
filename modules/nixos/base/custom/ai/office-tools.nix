# ===============================================================================
#
# Office document toolchain for AI agents - read/write Excel / Word / PowerPoint
# and render documents to per-page PNG images for visual verification.
#
# Shared base (enable = true): LibreOffice headless (`soffice`), poppler
# (`pdftoppm`), ONE python3.withPackages environment (pandas + the packages the
# excel/word/ppt switches select) and the `office-render` helper:
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
#   python -c "import openpyxl, docx, pptx, pandas"
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

  # office-render <file> [outdir] [dpi]: headless soffice -> PDF -> pdftoppm PNG images.
  # Each run gets a private UserInstallation profile so concurrent invocations
  # (parallel agents) never fight over the same LibreOffice profile lock.
  officeRender = pkgs.writeShellApplication {
    name = "office-render";
    runtimeInputs = [
      libreoffice
      poppler
      pkgs.coreutils
    ];
    text = ''
      if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
        echo "usage: office-render <file> [outdir] [dpi]" >&2
        exit 1
      fi
      file=$1
      outdir=''${2:-.}
      dpi=''${3:-100}
      if [ ! -f "$file" ]; then
        echo "office-render: no such file: $file" >&2
        exit 1
      fi
      case "$dpi" in
        "" | *[!0-9]*)
          echo "office-render: dpi must be a positive integer, got: $dpi" >&2
          exit 1
          ;;
      esac
      stem=$(basename "$file")
      stem=''${stem%.*}
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      mkdir -p "$outdir"
      # Fresh profile per invocation; the intermediate PDF stays in $work.
      soffice -env:UserInstallation="file://$work/profile" \
        --headless --norestore --convert-to pdf --outdir "$work" "$file"
      if [ ! -f "$work/$stem.pdf" ]; then
        echo "office-render: LibreOffice did not produce $stem.pdf" >&2
        exit 1
      fi
      pdftoppm -png -r "$dpi" "$work/$stem.pdf" "$outdir/$stem"
      for png in "$outdir/$stem"*.png; do
        [ -e "$png" ] || continue
        realpath "$png"
      done
    '';
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
      pythonEnv
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
