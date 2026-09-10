#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import os, subprocess, sys

CACHIX_CACHE = "dataeraserc"

ITEMS = [
    "nixosConfigurations.ai-niri.config.boot.kernelPackages.kernel",
    # future items go here
]


def main():
    failed = []
    for item in ITEMS:
        print(f"=== building: {item}")
        p = subprocess.run(["nix", "build", f".#{item}", "--print-build-logs"])
        if p.returncode != 0:
            failed.append(item)
            continue
        subprocess.run(["cachix", "push", CACHIX_CACHE, "./result"], check=True)
        os.remove("./result")
    if failed:
        print(f"failed: {failed}", file=sys.stderr)
        sys.exit(1)
    print("done")


if __name__ == "__main__":
    main()
