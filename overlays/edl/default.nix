_:
(_: super: {
  edl = super.edl.overrideAttrs (
    oldAttrs@{
      postInstall ? "",
      ...
    }:
    let
      new_postInstall = ''
        ${postInstall}
        [ -f $out/LICENSE ] && rm $out/LICENSE
        [ -f $out/README.md ] && rm $out/README.md
      '';
    in
    {
      postInstall = new_postInstall;
    }
  );
})
