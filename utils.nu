def repeat-str [s: string, n: int] {
  (1..$n | each { $s } | str join)
}

# ================= NixOS related =========================

export def nixos-switch [
    name: string
    mode: string
    verbosity: string
] {
    if $mode not-in ["switch" "boot"] {
        error make { msg: $"unsupported deployment mode '($mode)'; expected switch or boot" }
    }
    if $verbosity not-in ["normal" "debug"] {
        error make { msg: $"unsupported verbosity '($verbosity)'; expected normal or debug" }
    }

    print $"nixos-switch '($name)' in '($mode)' mode with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    if $verbosity == "debug" {
        # show details via nix-output-monitor
        nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --accept-flake-config --show-trace --verbose
        nixos-rebuild $mode --sudo --flake $".#($name)" --accept-flake-config --show-trace --verbose
    } else {
        nixos-rebuild $mode --sudo --flake $".#($name)" --accept-flake-config
    }
}


# Run `nix build` in a user systemd scope with the client-side memory limits
# from vars/nix-build-guard.nix. Builders themselves run under
# nix-daemon.service; this protects the eval/coordinator process. Requires a
# per-user systemd manager (loginctl enable-linger). Pass derivation targets
# only; `--no-link --print-build-logs` are added here.
export def nix-build-limited [...targets: string] {
    let guard = (nix eval --json --impure --expr 'import ./vars/nix-build-guard.nix' | from json)
    let max = $"MemoryMax=($guard.clientMemoryMax)"
    let swap = $"MemorySwapMax=($guard.clientMemorySwapMax)"
    systemd-run --user --scope --quiet -p $max -p $swap -- nix build --no-link --print-build-logs ...$targets
}


# ====================== Misc =============================

export def make-editable [
    path: string
] {
    print (repeat-str "=" 50)
    let tmpdir = (mktemp -d)
    rsync -avz --copy-links $"($path)/" $tmpdir
    rsync -avz --copy-links --chmod=D2755,F744 $"($tmpdir)/" $path
}


# ================= macOS related =========================

export def darwin-build [
    name: string
    verbosity: string
] {
    print $"darwin-build '($name)' with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    let target = $".#darwinConfigurations.($name).system"
    if "debug" == $verbosity {
        nom build $target --extra-experimental-features "nix-command flakes"  --show-trace --verbose
    } else {
        nix build $target --extra-experimental-features "nix-command flakes"
    }
}

export def darwin-switch [
    name: string
    verbosity: string
] {
    print $"darwin-switch '($name)' with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    if "debug" == $verbosity {
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $".#($name)" --show-trace --verbose
    } else {
        sudo -E ./result/sw/bin/darwin-rebuild switch --flake $".#($name)"
    }
}

export def darwin-rollback [] {
    # darwin-rebuild refuses switch/activate/rollback/check unless it runs as root.
    sudo -E ./result/sw/bin/darwin-rebuild --rollback
}

# Re-export the downstream command module; see utils.d/downstream.nu.
# Keep this at EOF: a trailing `export use ... *` overrides the same-named defs
# above it, while a leading one loses to them (nushell resolves later bindings).
export use ./utils.d/downstream.nu *
