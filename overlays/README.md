# Overlays

Overlays for both NixOS and Nix-Darwin.

If you don't know much about overlays, it is recommended to learn the function and usage of overlays
through [Overlays - NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays).

## Current Structure

```
overlays/
├── README.md
├── default.nix            # Entrypoint for all overlays
├── computer-use-linux.nix # computer-use-linux from ryan4yin/nur-packages
├── cua-driver.nix         # cua-driver from ryan4yin/nur-packages
├── pinentry-dispatch/     # pinentry that picks curses or Qt per caller
│   ├── default.nix
│   └── pinentry.sh
└── smartctl-exporter/     # smartctl_exporter pinned to the #329 fix
    └── default.nix
```

## Components

### 1. `default.nix`

The entrypoint imports every overlay file in this directory and applies it to the given arguments.

### 2. Package overlays

- `computer-use-linux.nix`: exposes `computer-use-linux` from the `nur-ryan4yin` flake input.
- `cua-driver.nix`: exposes `cua-driver` from the `nur-ryan4yin` flake input (used by the
  computer-use VMs).
- `pinentry-dispatch/`: installs a `pinentry` that draws in the terminal for terminal callers
  (`pass`, git signing) and opens the Qt dialog for GUI callers (a browser's pass extension);
  `pinentry.sh` makes the choice at runtime from `GPG_TTY` and a probed display. It is a directory
  because `default.nix` imports every entry of `overlays/`, so the script cannot sit beside the
  overlay file.
- `smartctl-exporter/`: pins `prometheus-smartctl-exporter` to the upstream commit carrying PR
  [#329](https://github.com/prometheus-community/smartctl_exporter/pull/329) until nixpkgs provides
  a version containing the fix; see `overlays/smartctl-exporter/default.nix`.
