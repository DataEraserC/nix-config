# Downstream-only nu commands, re-exported by utils.nu so the Justfile's
# `use {{utils_nu}} *` keeps seeing one flat namespace. Keep utils.nu itself
# byte-identical to upstream (the `export use` line is the only delta): when
# upstream edits nixos-switch or repeat-str here, port the change into this
# file instead of merging it into utils.nu.
export def repeat-str [s: string, n: int] {
  (1..$n | each { $s } | str join)
}

# ================= NixOS related =========================

# Run nix command with environment variables and --impure flag
export def run-nix-impure [cmd: string] {
  NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 ^$"($cmd) --impure"
}

# ================= ntfy related =========================

# 读取 ntfy topic:先判断环境变量 NTFY_TOPIC 是否存在且非空;
# 否则回退到 agenix 部署的 topic 环境文件(与 notify-me.sh 等仓库脚本
# 同一约定,NTFY_TOPIC_FILE 可覆盖路径),文件内容为 NTFY_TOPIC=<topic>。
# 拿不到 topic 时返回空字符串,由调用方跳过推送。
export def read-ntfy-topic [] {
    # 1. 先判断环境变量是否存在
    if "NTFY_TOPIC" in $env {
        let topic = ($env.NTFY_TOPIC | str trim)
        if $topic != "" {
            return $topic
        }
    }
    # 2. 回退到 topic 环境文件
    let topic_file = if "NTFY_TOPIC_FILE" in $env {
        $env.NTFY_TOPIC_FILE
    } else {
        "/etc/agenix/ntfy-topic.env"
    }
    if (($topic_file | path type) != "file") {
        return ""
    }
    let matched = (open --raw $topic_file | lines | where {|line| $line =~ '^\s*(export\s+)?NTFY_TOPIC=' })
    if ($matched | is-empty) {
        return ""
    }
    $matched | first | str replace -r '^\s*(export\s+)?NTFY_TOPIC=' '' | str trim
}

# Best-effort ntfy 推送:notify 模式在 notify-send 之外同步推送到 ntfy。
# topic 缺失、ntfy 不可用或发布失败都只写 stderr,绝不影响 nixos-switch
# 的执行结果与退出码;不在代码里硬编码 topic。
export def ntfy-publish [event: string, msg: string, --failed] {
    try {
        let topic = (read-ntfy-topic)
        if $topic == "" {
            print --stderr "ntfy-publish: NTFY_TOPIC not found (env var or topic file), skip ntfy push"
            return
        }
        let host = (sys host | get hostname)
        # 失败用 warning,成功用 robot;priority high 对齐 notify-send 的 -u critical
        let tags = if $failed { "warning" } else { "robot" }
        ntfy publish --title $"($host) · ($event)" --tags $tags --priority high --markdown $topic $msg | ignore
    } catch {|error|
        print --stderr $"ntfy-publish: ntfy push failed: ($error.msg)"
    }
}

export def nixos-switch [
    name: string
    mode: string
    verbosity: string
] {
    # 有效的 mode 值
    let allowed_modes = ["switch", "boot", "boot-notify", "switch-notify"]
    if $mode not-in $allowed_modes {
        error make { msg: $"unsupported deployment mode '($mode)'; expected one of ($allowed_modes | str join ', ')" }
    }
    if $verbosity not-in ["normal", "debug"] {
        error make { msg: $"unsupported verbosity '($verbosity)'; expected normal or debug" }
    }

    print $"nixos-switch '($name)' in '($mode)' mode with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")

    # 根据 verbosity 决定是否使用 nom 和详细标志
    let use_nom = $verbosity == "debug"
    let verbose_flags = if $use_nom { ["--show-trace", "--verbose"] } else { [] }

    if $mode == "switch" {
        try {
            if $use_nom {
                print $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nom build $\".#nixosConfigurations.($name).config.system.build.toplevel\" --show-trace --verbose"
                NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --show-trace --verbose
            }
            let cmd = if $use_nom {
                $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --sudo --flake $\".#($name)\" --show-trace --verbose --impure"
            } else {
                $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --sudo --flake $\".#($name)\" --impure"
            }
            print $cmd
            if $use_nom {
                NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --sudo --flake $".#($name)" --show-trace --verbose --impure
            } else {
                NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --sudo --flake $".#($name)" --impure
            }
            let msg = $"NixOS switch completed successfully for '($name)'"
            print $msg
            notify-send -u normal -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg -w
        } catch {|error|
            let msg = $"NixOS switch failed for '($name)': ($error.msg)"
            print $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg
            return
        }
    } else if $mode == "boot" {
        try {
            let cmd = if $use_nom {
                $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot --sudo --flake $\".#($name)\" --show-trace --verbose --impure"
            } else {
                $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot --sudo --flake $\".#($name)\" --impure"
            }
            print $cmd
            if $use_nom {
                NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot --sudo --flake $".#($name)" --show-trace --verbose --impure
            } else {
                NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot --sudo --flake $".#($name)" --impure
            }
            let msg = $"NixOS boot completed successfully for '($name)'"
            print $msg
            notify-send -u normal -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg -w
        } catch {|error|
            let msg = $"NixOS boot failed for '($name)': ($error.msg)"
            print $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg
            return
        }
    } else if $mode == "boot-notify" {
        let new_dir_name = $"result-(date now | format date "%Y-%m-%d_%H:%M:%S")"
        try {
            print $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $\".#($name)\" --impure"
            NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $".#($name)" --impure
            mv result $new_dir_name
            let msg = "NixOS boot image built successfully. sudo password is required now"
            print $msg
            ntfy-publish "nixos boot built" $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg -w
            sudo nix-env -p /nix/var/nix/profiles/system --set $"./($new_dir_name)"
            rm $new_dir_name
        } catch {|error|
            let msg = $"NixOS boot build failed for '($name)': ($error.msg)"
            print $msg
            ntfy-publish "nixos boot build failed" $msg --failed
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg
            if ($new_dir_name | path exists) {
                rm $new_dir_name
            }
            return
        }
    } else if $mode == "switch-notify" {
        let new_dir_name = $"result-(date now | format date "%Y-%m-%d_%H:%M:%S")"
        try {
            print $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $\".#($name)\" --impure"
            NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $".#($name)" --impure
            mv result $new_dir_name
            let msg = "NixOS system configuration built successfully. sudo password is required now"
            print $msg
            ntfy-publish "nixos switch built" $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg -w
            sudo nix-env -p /nix/var/nix/profiles/system --set $"./($new_dir_name)"
            sudo systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER --collect --no-ask-password --pipe --quiet --service-type=exec --unit=nixos-rebuild-switch-to-configuration $"($new_dir_name)/bin/switch-to-configuration" switch
            rm $new_dir_name
        } catch {|error|
            let msg = $"NixOS switch build failed for '($name)': ($error.msg)"
            print $msg
            ntfy-publish "nixos switch build failed" $msg --failed
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg
            if ($new_dir_name | path exists) {
                rm $new_dir_name
            }
            return
        }
    } else {
        # 默认 fallback（与原 else 分支一致）
        let new_dir_name = $"result-(date now | format date "%Y-%m-%d_%H:%M:%S")"
        try {
            print $"NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $\".#($name)\" --impure"
            NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild build --flake $".#($name)" --impure
            mv result $new_dir_name
            let msg = "NixOS system configuration built successfully. sudo password is required now"
            print $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg -w
            sudo nix-env -p /nix/var/nix/profiles/system --set $"./($new_dir_name)"
            sudo systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER --collect --no-ask-password --pipe --quiet --service-type=exec --unit=nixos-rebuild-switch-to-configuration $"($new_dir_name)/bin/switch-to-configuration" switch
            rm $new_dir_name
        } catch {|error|
            let msg = $"NixOS switch build failed for '($name)': ($error.msg)"
            print $msg
            notify-send -u critical -a "nixos-rebuild" -p $"NIXOS_REBUILD_($timestamp)" $msg
            if ($new_dir_name | path exists) {
                rm $new_dir_name
            }
            return
        }
    }
}

# ================= NixOnDroid related =========================

export def nod-switch [
    name: string
    mode: string
] {
    print $"mode: ($mode)"
    if "debug" == $mode {
        # show details via nix-output-monitor
        NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nom build $"nixOnDroidConfigurations.#.($name).config.system.build.toplevel" --show-trace --verbose
        NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nix-on-droid switch --flake $".#($name)" --show-trace --verbose
    } else {
        NIXPKGS_ALLOW_BROKEN=1 NIXPKGS_ALLOW_INSECURE=1 NIXPKGS_ALLOW_UNFREE=1 nix-on-droid switch --flake $".#($name)"
    }
}

# ====================== Misc =============================
