_: final: prev: {
  # nixpkgs' pi-coding-agent is pinned to 0.80.3, too old for extensions
  # requiring pi >= 0.81.0 (e.g. pi-free 2.4.4). Build the newer version from
  # the upstream GitHub source tree (no new nixpkgs input), npm deps fetched
  # from the (fast) npm registry. Exposed under a distinct name so the nixpkgs
  # `pi-coding-agent` package stays untouched.
  #
  # Provider model data (`packages/ai/src/providers/data/*.json`) is not
  # committed to the repo since newer pi versions; it ships in the
  # `@earendil-works/pi-ai` npm tarball and is extracted in `postPatch`.
  #
  # We override `npmDeps` explicitly because `overrideAttrs` only changes
  # version/src/npmDepsHash but `extendMkDerivation` captures `npmDeps` against
  # the original args (the old version's fetchNpmDeps), so it would still build
  # the old deps.
  #
  # Update `version`, `src.hash`, `aiData.hash` and `npmDepsHash` when bumping.
  pi-coding-agent-unstable = prev.pi-coding-agent.overrideAttrs (
    old:
    let
      version = "0.84.1";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${version}";
        hash = "sha256-lg+I4S/aAjazjhGZU567ow+rksoNiqOqjHl//TjAMes=";
      };

      aiData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
        hash = "sha256-araJGJ58s95c2xJjEqPmDorDX+XuXxtj0A9xHIpDDHM=";
      };
    in
    {
      __intentionallyOverridingVersion = true;
      inherit version src;

      postPatch = ''
        if ! tar -tzf ${aiData} package/dist/providers/data >/dev/null 2>&1; then
          echo "ERROR: expected package/dist/providers/data not found in ${aiData}" >&2
          echo "The pi-ai tarball layout changed; update the extraction path in postPatch." >&2
          exit 1
        fi
        tar -xzf ${aiData} --strip-components=3 -C packages/ai/src/providers package/dist/providers/data
      '';

      # packages/* depend on each other via workspace symlinks; build them in
      # dependency order (mirrors the repo's `build:offline` script) so each
      # package's dist/ output exists when the next one compiles.
      buildPhase = ''
        runHook preBuild

        npx tsgo -p packages/telemetry/tsconfig.build.json
        npx tsgo -p packages/protocol/tsconfig.build.json
        npx tsgo -p packages/ai/tsconfig.build.json
        npx tsgo -p packages/tui/tsconfig.build.json
        npx tsgo -p packages/agent/tsconfig.build.json
        npx tsgo -p packages/session-backends/sqlite-node/tsconfig.build.json
        npx tsgo -p packages/client/tsconfig.build.json
        npm run build --workspace=packages/coding-agent

        runHook postBuild
      '';

      # 0.84.1 splits more runtime deps into workspace packages than 0.80.3
      # did; replace every @earendil-works workspace symlink with a real copy
      # so the output no longer references packages/ (which isn't installed).
      postInstall = ''
        local nm="$out/lib/node_modules/pi-monorepo/node_modules"

        for ws in @earendil-works/pi-ai:packages/ai \
                  @earendil-works/pi-agent-core:packages/agent \
                  @earendil-works/pi-tui:packages/tui \
                  @earendil-works/pi-telemetry:packages/telemetry \
                  @earendil-works/pi-protocol:packages/protocol \
                  @earendil-works/pi-client:packages/client; do
          IFS=: read -r pkg src <<< "$ws"
          rm -f "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done

        # Delete remaining workspace symlinks
        find "$nm" -type l -lname '*/packages/*' -delete

        # Clean up now-dangling .bin symlinks
        find "$nm/.bin" -xtype l -delete
      '';

      npmDeps = final.fetchNpmDeps {
        inherit src;
        name = "pi-coding-agent-${version}-npm-deps";
        hash = "sha256-tufyZQRPAUeDtiq0UQodbKA/Y9xUAvNT8K+NWFjkeME=";
      };
    }
  );
}
