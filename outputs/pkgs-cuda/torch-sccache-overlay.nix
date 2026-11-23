{ lib }:
final: prev:
let
  socketPath = "/run/sccache/sccache.sock";

  # sccache 0.19.0 panics when CUDA 13.5 omits PATH from nvcc --dryrun.
  # This upstream fix is merged and can be removed after nixpkgs updates it.
  sccacheNvcc = final.sccache.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (final.fetchpatch {
        name = "sccache-nvcc-inherited-path.patch";
        url = "https://github.com/mozilla/sccache/commit/0362a03bf3b36dbed2e606c257ac1f0bdb06f300.patch";
        hash = "sha256-lulVwvMCDsh/bdA8++O3ZCZiqEeMJrKgf6TytNw9GZQ=";
      })
    ];
  });

  cudaNvcc = final.cudaPackages.cuda_nvcc;

  # sccache resolves compilers by basename. Expose nixpkgs' real NVCC behind a
  # normal `nvcc` name while preserving the original host compiler arguments.
  nvccProxy = final.runCommand "sccache-nvcc-proxy" { } ''
    mkdir -p "$out/bin"
    ln -s ${cudaNvcc}/bin/.nvcc-wrapped "$out/bin/nvcc"
  '';

  # CMake launchers receive the real compiler as argv[1]. Builders without the
  # local socket (remote hosts and clean sandboxes) fall through unchanged.
  launcher = final.writeShellScript "torch-sccache-launcher" ''
    if [[ -S ${socketPath} && -w ${socketPath} ]]; then
      compiler="$1"
      shift

      compilerName="''${compiler##*/}"
      compilerDir="''${compiler%/*}"
      if [[ "$compilerName" == nvcc && -x "$compilerDir/.nvcc-wrapped" ]]; then
        export PATH=${nvccProxy}/bin:${cudaNvcc}/bin:${cudaNvcc}/nvvm/bin:"$PATH"
        compiler=nvcc
      fi

      export SCCACHE_SERVER_UDS=${socketPath}
      export SCCACHE_CLIENT_SIDE=1
      exec ${lib.getExe sccacheNvcc} "$compiler" "$@"
    fi

    exec "$@"
  '';
  launcherPath = toString launcher;
in
{
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_pythonFinal: pythonPrev: {
      torch = pythonPrev.torch.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ sccacheNvcc ];

        # Nix's GCC wrappers are not sccache compiler proxies. Scope caching to
        # NVCC until upstream supports those wrappers too.
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          (lib.cmakeFeature "CMAKE_CUDA_COMPILER_LAUNCHER" launcherPath)
        ];

        passthru = (old.passthru or { }) // {
          sccacheCudaEnabled = true;
          sccacheLauncher = launcher;
          sccachePackage = sccacheNvcc;
        };
      });
    })
  ];
}
