_:
(_: super: {
  patched_tomcat9 = super.tomcat9.overrideAttrs (
    oldAttrs@{
      installPhase ? "",
      postInstall ? "",
      ...
    }:
    let
      new_installPhase = ''
        runHook preInstall
        ${installPhase}
        runHook postInstall

      '';
      new_postInstall = ''
        ${postInstall}
        [ -f $out/CONTRIBUTING.md ] && rm $out/CONTRIBUTING.md
        [ -f $out/BUILDING.txt ] && rm $out/BUILDING.txt
        [ -f $out/LICENSE ] && rm $out/LICENSE
        [ -f $out/README.md ] && rm $out/README.md
      '';
    in
    {
      postInstall = new_postInstall;
      installPhase = new_installPhase;
    }
  );
})
