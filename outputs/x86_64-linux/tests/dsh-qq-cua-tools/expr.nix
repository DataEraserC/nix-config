{
  lib,
  outputs,
  ...
}:
let
  cfg = outputs.nixosConfigurations.ai-niri.config;
  presets = builtins.head (
    builtins.filter (
      b: (b.passthru.extraAllowedTools or null) != null
    ) cfg.programs.dsh.profiles."web-qq".bundles
  );
  allow = presets.passthru.extraAllowedTools;
  deny = presets.passthru.extraRestrictedTools;
  cuaPrefix = "mcp__cua-mcp__";
  cuaAllow = builtins.filter (lib.hasPrefix cuaPrefix) allow;
  cuaDeny = builtins.filter (lib.hasPrefix cuaPrefix) deny;
  # Families the QQ surface must keep: sandbox lifecycle either way, plus the
  # container-internal desktop/files/clipboard/shell set. Anything outside the
  # container (teleport/volume/cloud/agent/routine/space registry) is denied.
  mustAllow = [
    "sandbox_create"
    "sandbox_open_browser"
    "computer_screenshot"
    "computer_click"
    "computer_clipboard_set"
    "computer_shell"
    "computer_file_write"
  ];
  mustDeny = [
    "teleport_app"
    "teleport_browser_session"
    "request_site_login"
    "volume_write"
    "volume_grant"
    "cloud_connect"
    "agent_start"
    "persistent_agent_send"
    "routine_add"
    "computer_access_grant"
    "add_space"
    "space_bash"
    "call_tool"
  ];
  named = names: map (n: cuaPrefix + n) names;
in
{
  # 两个名单必须严格不相交：重合项在 extraAllowedTools 里会被
  # KNOWN_DANGEROUS_GLOBAL_TOOLS 前置跳过，结果取决于注入顺序而不是声明，
  # 是"声明了但没生效"的经典静默失效。
  listsDisjoint =
    builtins.intersectAttrs (lib.genAttrs allow (_: true)) (lib.genAttrs deny (_: true)) == { };

  # 每个 cua 名字都必须带 mcp__cua-mcp__ 前缀（前缀写错 → 名字永远匹配不上，
  # 守卫照旧拒绝，但 QQ 会话里会少一个本该可用的工具，且没有任何报错）。
  allPrefixed = lib.all (lib.hasPrefix cuaPrefix) (cuaAllow ++ cuaDeny);

  # 沙盒内部能力必须在放行侧。
  allowsSandboxSurface = lib.all (n: lib.elem n cuaAllow) (named mustAllow);

  # 沙盒外部能力必须在拒绝侧（执行期 guard + schema restrict 都会生效）。
  deniesHostSurface = lib.all (n: lib.elem n cuaDeny) (named mustDeny);
}
