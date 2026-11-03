# GNOME Shell extension used by the optional
# modules.desktop.gnome-wayland.rdpPrimaryMonitor switch. It is built here
# instead of referenced from nur-DataEraserC because the locked NUR revision
# does not expose the package yet. Keep the pin in sync with the NUR package
# (`rdp-primary-monitor`, upstream commit b537918949ee7ce6117845ade412ba2c9569a5b1).
_: _final: prev: {
  rdp-primary-monitor = prev.stdenvNoCC.mkDerivation {
    pname = "rdp-primary-monitor";
    version = "0.1.0-unstable-2026-10-26";
    src = prev.fetchFromGitHub {
      owner = "michal-b-bozek";
      repo = "rdp-primary-monitor";
      rev = "b537918949ee7ce6117845ade412ba2c9569a5b1";
      hash = "sha256-O7iQ1zIYV8L8UDLvec0QDNxpW5hkZvsvIhKXoJHo8WU=";
    };

    nativeBuildInputs = [
      prev.glib
      prev.jq
    ];

    buildPhase = ''
      runHook preBuild
      glib-compile-schemas --strict src/schemas
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      extension="$out/share/gnome-shell/extensions/rdp-primary-monitor@michal-b-bozek.github.io"
      mkdir -p "$extension"
      cp -r src/. "$extension"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      extension="$out/share/gnome-shell/extensions/rdp-primary-monitor@michal-b-bozek.github.io"
      test -f "$extension/metadata.json"
      test -f "$extension/extension.js"
      test -f "$extension/schemas/gschemas.compiled"
      test "$(jq -r .uuid "$extension/metadata.json")" = "rdp-primary-monitor@michal-b-bozek.github.io"
      runHook postInstallCheck
    '';

    meta = {
      description = "GNOME Shell extension that makes an RDP client's virtual monitor primary in extend mode";
      homepage = "https://github.com/michal-b-bozek/rdp-primary-monitor";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.linux;
    };
  };
}
