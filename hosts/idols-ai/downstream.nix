# Downstream module wiring for the idols-ai host, kept in a purely-additive
# file so hosts/idols-ai/default.nix stays as close to upstream as possible.
# Everything here is ours: enable flags, registry-consumed service options and
# the svc helper (one registry row: vars.networking.services.<name>.hosts.idols-ai).
{
  config,
  lib,
  pkgs,
  pkgs-cuda,
  inputs,
  myvars,
  ...
}:
let
  inherit (config.networking) hostName;
  serviceHost = "idols-ai";
  svc = service: myvars.networking.services.${service}.hosts.${serviceHost};

  # Auto-shutdown probe conditions (used by modules.auto-shutdown below).
  pingCondition = name: ip: {
    inherit name;
    command = pkgs.writeShellScript "auto-shutdown-${lib.replaceStrings [ " " ] [ "-" ] name}" ''
      exec ${pkgs.iputils}/bin/ping -c 1 -W 2 ${ip}
    '';
  };
in
{
  # Boot-menu name for this generation. systemd-boot/lanzaboote builds the entry
  # title from bootspec's label, which is system.nixos.label and appends the
  # generation number (plus date) itself; the label defaults to
  # "<tags>-<nixpkgs version>". Naming the running desktop variant through
  # system.nixos.tags keeps the nixpkgs version string the entries always showed
  # and only prefixes it, so the three configurations stay distinguishable
  # instead of all reading "26.11.20261115.1c872b8":
  #   ai-niri-26.11.20261115.1c872b8 (Generation 42, ...)
  system.nixos.tags = [
    (
      if config.modules.desktop.niri.enable then
        "ai-niri"
      else if config.modules.desktop.gnome-wayland.enable then
        "ai-gnome-wayland"
      else if config.modules.desktop.kde-wayland.enable then
        "ai-kde-wayland"
      else
        "ai"
    )
  ];

  # One unprivileged server owns the persistent cache; build sandboxes only see
  # its Unix socket, and pkgs-cuda's torch falls back when the socket is absent.
  modules.sccache = {
    enable = true;
    package = pkgs-cuda.python314Packages.torch.sccachePackage;
    cacheSize = "32G";
  };

  # dae transparent proxy - the shared module lives in
  # modules/nixos/base/custom/network/dae.nix and is only enabled on this host for now.
  # Its main config is the host-local ./config.dae, the subscription comes from agenix.
  modules.dae = {
    enable = true;
    # dae fetches subscriptions only at startup/reload, so reload once an hour to
    # pick up Sub-Store's refreshed node lists; the oneshot skips while dae is
    # stopped (e. while it is kept off to avoid a rebuild failure).
    autoReload = {
      enable = true;
      interval = "60min";
    };
    installFiles = [
      {
        source = ./config.dae;
        target = "/etc/dae/config.dae";
      }
      {
        source = config.age.secrets."dae-subscription.dae".path;
        target = "/etc/dae/config.d/subscription.dae";
      }
    ];
  };
  # Static service overview page (modules/nixos/base/custom/services/homepage).
  # Port, bind address and enable state come from services.homepage.hosts.idols-ai;
  # the page lists every registry service that carries a catalog block.
  modules.homepage = {
    enable = (svc "homepage").enable;
    host = (svc "homepage").host;
    port = (svc "homepage").port;
    hostKey = serviceHost;
  };
  # Sub-Store converts Clash-format subscriptions into base64 v2ray URI lists
  # that dae can fetch (dae has no Clash-YAML parser). Caddy fronts API 24500 and
  # web panel 24501 with Basic Auth (agenix secret sub-store.caddy), the panel
  # calling its API on the same 24501 origin (no cross-port CORS); Sub-Store
  # itself sits on loopback internal ports behind it. Passwordless on purpose:
  # loopback (dae, local panel) and every GET /download/* subscription link.
  # The host firewall still only trusts tailscale/zerotier/easytier, so
  # openFirewall stays off - flip it on later to reach the ports from the campus
  # LAN (asserted to require auth.enable).
  # See modules/nixos/base/custom/network/sub-store/default.nix.
  modules.sub-store = {
    enable = (svc "sub-store").enable;
    host = (svc "sub-store").host;
    auth = {
      enable = true;
      file = config.age.secrets."sub-store.caddy".path;
    };
    # Re-fetch every registered upstream hourly so /download/<name>/v2ray always
    # serves fresh nodes plus a #cacheKey disk fallback for dae's cold start.
    autoRefresh = {
      enable = true;
      interval = "60min";
      subs = [
        "GarbageDump1"
        "iKuuu1"
        "iKuuu2"
        "Mojie1"
        "Xxmad1"
      ];
    };
  };
  # ACB：开关、绑定地址和端口全部读 services.acb 注册表。
  modules.acb = {
    enable = (svc "acb").enable;
    host = (svc "acb").host;
    exposeHost = (svc "acb").exposeHost;
    endpointPort = (svc "acb").ports.endpoint;
    consolePort = (svc "acb").ports.console;
    relayPort = (svc "acb").ports.relay;
    secretsFile = config.age.secrets."acb.env".path;
  };
  # ntfy notifications on network up/down events(NM dispatcher, shared script)
  modules.network-event-notify = {
    enable = true;
    inherit hostName;
  };
  # periodic host liveness heartbeat via ntfy
  modules.host-heartbeat = {
    enable = true;
    interval = "30min";
    inherit hostName;
    username = myvars.username;
  };
  # ntfy warnings when the AC power supply is unplugged/restored(udev-driven)
  modules.power-event-notify = {
    enable = true;
    inherit hostName;
  };
  # one-shot cpolar tunnel status report after boot
  modules.cpolar-status = {
    enable = true;
    inherit hostName;
    username = myvars.username;
  };
  # Oray PgyVisitor SDN client
  modules.pgy.enable = true;
  # EasyTier decentralized P2P VPN
  modules.easytier.enable = true;
  # Authenticated SOCKS5 + HTTP proxy (shared
  # modules/nixos/base/custom/network/gost-proxy.nix).
  # Two listeners on every interface, but the firewall only trusts the overlay
  # interfaces (easytier/tailscale/zerotier) and openFirewall stays off, so the
  # campus LAN cannot connect - proxy credentials are clear text there.
  # Credentials come from the agenix secret gost-proxy.auth.
  #   - idols-ai-socks5 (1080): for curl / ssh / proxychains. This is also the
  #     chained upstream of wsl-work's idols-ai-socks5 (31080) and
  #     idols-ai-http (31081) entry points, whose clients reach this host's
  #     loopback (dsh GUI on 127.0.0.1:3080) through it.
  #   - idols-ai-http (1081): the same proxy for browsers, which cannot send
  #     SOCKS5 credentials (Chromium not at all, Firefox only via about:config).
  # They are independent instances, so either one can be retired later with
  # `instances.<name>.enable = false` without touching the other.
  modules.gost-proxy = {
    enable = (svc "gost-proxy").enable;
    instances = {
      idols-ai-socks5.port = (svc "gost-proxy").ports.idols-ai-socks5;
      idols-ai-http = {
        port = (svc "gost-proxy").ports.idols-ai-http;
        protocol = "http";
      };
    };
  };
  # CLIProxyAPI proxy with an offline management panel, bound to 0.0.0.0:1105.
  modules.cliproxyapi.enable = (svc "cliproxyapi").enable;
  modules.cliproxyapi.port = (svc "cliproxyapi").port;
  # M365 Copilot2API gateway, bound to 0.0.0.0:1104.
  modules.m365-copilot2api.enable = (svc "m365-copilot2api").enable;
  modules.m365-copilot2api.port = (svc "m365-copilot2api").port;
  # Agent2API gateway, bound to 0.0.0.0:1108 (API and management panel).
  modules.agent2api.enable = (svc "agent2api").enable;
  modules.agent2api.port = (svc "agent2api").port;
  # Provider packs from the agent2api-nix flake; managed mode reconciles this
  # set (and the provider switches) on every start.
  modules.agent2api.plugins = with inputs.agent2api-nix.packages.${pkgs.stdenv.hostPlatform.system}; [
    # The native pack already provides trae/zcode/zcode-intl; the wasm
    # packs need a wasm-capable gateway and fail on the headless 3.4.2
    # server with "Exec format error".
    agent2api-providers
    agent2api-web-providers
  ];
  # WebMux browser terminal server, bound to 0.0.0.0:1109 (runs as this host's
  # login user so sessions reach its agent logins and HOME).
  modules.webmux.enable = (svc "webmux").enable;
  modules.webmux.host = (svc "webmux").host;
  modules.webmux.port = (svc "webmux").port;
  # Stable agent key with direct and wrapped command forms. The legacy
  # `multi-instance codebuddy 1` binding remains because launch-configs.json is
  # seeded once; canonical accounts 1 through 8 all reuse the historical
  # codebuddy/<instance> state directories. The title names the proxy, not the
  # vendor CLI: plain `codebuddy` lacks ACP session/list, so only this -acp
  # command actually supports the chat view.
  modules.webmux.acpAgents.codebuddy-acp = {
    title = "CodeBuddy ACP";
    icon = "codebuddy";
    processExecutables = [
      "codebuddy"
      "cbc"
    ];
    commands = [
      {
        match = [ "codebuddy-acp" ];
        acp = [
          "codebuddy-acp"
          "--acp"
        ];
        resume = [
          "codebuddy-acp"
          "--resume"
        ];
      }
      {
        match = [
          "multi-instance"
          "codebuddy"
          "1"
        ];
        acp = [
          "multi-instance"
          "codebuddy"
          "1"
          "--acp"
        ];
        resume = [
          "multi-instance"
          "codebuddy"
          "1"
          "--resume"
        ];
        launcher = "bwrap";
      }
    ]
    ++ map (
      instance:
      let
        instanceName = toString instance;
      in
      {
        match = [
          "multi-instance"
          "codebuddy-acp"
          instanceName
        ];
        acp = [
          "multi-instance"
          "codebuddy-acp"
          instanceName
          "--acp"
        ];
        resume = [
          "multi-instance"
          "codebuddy-acp"
          instanceName
          "--resume"
        ];
        launcher = "bwrap";
      }
    ) (lib.range 1 8);
  };
  # ZCode agent, mirroring the codebuddy-acp shape. One adapter argv serves
  # both sides through TTY dispatch: under WebMux's PTY (the match/launch
  # form) bin/zcode-acp opens the bridge's own Martty chat TUI, and over
  # plain pipes (the acp form) the same command falls back to the stdio ACP
  # server - the official AppImage-bundled zcode-cli has no TUI of its own
  # (see ZC-02/ZC-04 in the NUR requirements doc). Resume goes through the
  # boot-resume wrapper, which turns the appended session id into the TUI's
  # boot-resume environment. Instances 1 through 6 keep isolated ~/.zcode logins
  # (log in once with `multi-instance zcode-cli N login`); the chat view
  # discovers the same session store via session/list. bin/zcode itself is
  # the GUI launcher, so no argv here may name it, and the icon must be one
  # of WebMux's launch-config icon keys (an unknown icon makes the loader
  # skip the whole declaration).
  modules.webmux.acpAgents.zcode-acp = {
    title = "ZCode";
    icon = "terminal";
    processExecutables = [
      "node"
      "bun"
    ];
    commands = [
      {
        match = [ "zcode-acp" ];
        acp = [ "zcode-acp-server" ];
        resume = [ "zcode-acp-resume" ];
      }
    ]
    ++ map (
      instance:
      let
        instanceName = toString instance;
      in
      {
        match = [
          "multi-instance"
          "zcode-acp"
          instanceName
        ];
        acp = [
          "multi-instance"
          "zcode-acp"
          instanceName
        ];
        resume = [
          "multi-instance"
          "zcode-acp-resume"
          instanceName
        ];
        launcher = "bwrap";
      }
    ) (lib.range 1 6);
  };
  # Qoder CN CLI, the terminal client of the Qoder CN desktop app. Only the
  # wrapped forms are declared here: bare `qoderclicn` is already a built-in
  # WebMux adapter (`qodercn`), and a declaration whose first matched argv names
  # a built-in executable is dropped for shadowing it, so adding a direct form
  # would delete this agent rather than extend it. Instances 1 and 2 match
  # `desktopAccounts.qoder-cn`, each with its own ~/.qoder-cn login (log in once
  # with `multi-instance qoderclicn N login`); the CLI serves ACP session/list, so
  # the chat view finds and resumes the sessions the terminal form creates.
  # International `qodercli` is packaged but off, like `modules.qoder`.
  modules.webmux.acpAgents.qoder-cli-cn = {
    title = "Qoder CLI CN";
    icon = "qoder";
    processExecutables = [ "qoderclicn" ];
    commands = map (
      instance:
      let
        instanceName = toString instance;
      in
      {
        match = [
          "multi-instance"
          "qoderclicn"
          instanceName
        ];
        acp = [
          "multi-instance"
          "qoderclicn"
          instanceName
          "--acp"
        ];
        resume = [
          "multi-instance"
          "qoderclicn"
          instanceName
          "--resume"
        ];
        launcher = "bwrap";
      }
    ) (lib.range 1 2);
  };
  # opencode2api gateway, bound to 0.0.0.0:1101 (API) and 0.0.0.0:1102 (WebUI).
  modules.opencode2api.enable = (svc "opencode2api").enable;
  modules.opencode2api.port = (svc "opencode2api").port;
  modules.opencode2api.webUiPort = (svc "opencode2api").adminPort;
  # mimocode2api gateway, bound to 0.0.0.0:1103 (VPN interfaces only).
  modules.mimocode2api.enable = (svc "mimocode2api").enable;
  modules.mimocode2api.port = (svc "mimocode2api").port;
  # meoo2api gateway and console, bound to 0.0.0.0:1110.
  modules.meoo2api.enable = (svc "meoo2api").enable;
  modules.meoo2api.port = (svc "meoo2api").port;
  # workbuddy2api gateway and panel, bound to 0.0.0.0:1111.
  modules.workbuddy2api.enable = (svc "workbuddy2api").enable;
  modules.workbuddy2api.port = (svc "workbuddy2api").port;
  # OmniRoute unified LLM gateway, bound to 0.0.0.0:1106.
  modules.omniroute.enable = (svc "omniroute").enable;
  modules.omniroute.port = (svc "omniroute").port;
  # new-api LLM gateway, port 1100 (upstream listens on all interfaces).
  modules.new-api.enable = (svc "new-api").enable;
  modules.new-api.port = (svc "new-api").port;
  # Our Free Model standalone gateway, 127.0.0.1:1107 (loopback only).
  modules.our-free-model-standalone.enable = (svc "our-free-model-standalone").enable;
  modules.our-free-model-standalone.port = (svc "our-free-model-standalone").port;
  # Open WebUI chat frontend, 0.0.0.0:1120 (shared modules.open-webui) - disabled.
  modules.open-webui.enable = (svc "open-webui").enable;
  modules.open-webui.port = (svc "open-webui").port;
  # alist (openlist) file listing, bound to 0.0.0.0:5244.
  modules.alist.enable = (svc "alist").enable;
  modules.alist.port = (svc "alist").port;
  modules.alist.s3Port = (svc "alist").s3Port;
  # AstrBot chatbot + WebUI, bound to 0.0.0.0:6185 (shared modules.astrbot).
  # Native deployment: the pinned upstream source runs on Nix's python312 with a
  # uv-provisioned venv under /var/lib/astrbot (see the module header); the
  # first start downloads the wheel set, so give it a few minutes.
  modules.astrbot.enable = (svc "astrbot").enable;
  modules.astrbot.port = (svc "astrbot").port;
  # Clash Verge Rev GUI client (shared modules/nixos/base/custom/network/clash-verge.nix,
  # nixpkgs programs.clash-verge with the package from nixpkgs-master). Service
  # mode runs the mihomo core as a root systemd unit; autoStart and TUN stay off
  # (dae owns transparent proxying here, so no second TUN stack).
  modules.clash-verge.enable = true;
  # Route CLI traffic through the local / LAN SOCKS proxies.
  modules.proxychains.enable = true;
  # Agent tools and AI IDEs from nur-DataEraserC: CodeBuddy ACP, WorkBuddy,
  # WorkBuddy International, LobsterAI, Trae CN, ZCode (one package serves the
  # CN and international editions; the region is the account you log in with),
  # Qoder CN, Qoder CN CLI, AutoClaw CN, AutoClaw International and Raccoon Work
  # are on. Qoder, Qoder IDE, Qoder CN IDE, Qoder CLI, Trae International and
  # CodeArts are packaged but off. Their state (~/.codebuddy,
  # ~/.codeartsdoer, ~/.workbuddy, ~/.workbuddy-ai,
  # ~/.local/share/CodeBuddyExtension, ~/.config/LobsterAI, ~/lobsterai,
  # ~/.trae-cn, ~/.trae, ~/.config/Trae CN, ~/.config/Trae, ~/.zcode,
  # ~/.config/ZCode, ~/.qoder, ~/.config/Qoder,
  # ~/.config/com.qoder.app.stable, ~/.qoder-cn, ~/.config/QoderCN,
  # ~/.config/com.qodercn.app.stable, ~/.config/autoclaw-cn,
  # ~/.config/autoclaw-intl, ~/.config/office-raccoon, ~/.box-agent,
  # ~/RaccoonWork, ~/.openclaw, ~/.hermes) is persisted unconditionally in
  # preservation-downstream.nix, so re-enabling one keeps the login and history
  # already on disk.
  # See modules/nixos/base/custom/ai/{codebuddy-acp,codearts,workbuddy,workbuddy-ai,lobsterai,trae-cn,trae-intl,zcode,zcode-acp,qoder,qoder-ide,qoder-cn,qoder-cn-ide,qodercli,qoderclicn,autoclaw-cn,autoclaw-intl,xiaohuanxiong}.nix.
  modules.codebuddy-acp.enable = true;
  modules.zcode-acp.enable = true;
  # modules.codearts.enable = true;
  modules.workbuddy.enable = true;
  modules.workbuddy-ai.enable = true;
  modules.lobsterai.enable = true;
  modules.trae-cn.enable = true;
  # modules.trae-intl.enable = true;
  modules.zcode.enable = true;
  # modules.qoder.enable = true;
  # modules.qoder-ide.enable = true;
  modules.qoder-cn.enable = true;
  # modules.qoder-cn-ide.enable = true;
  # modules.qodercli.enable = true;
  modules.qoderclicn.enable = true;
  modules.autoclaw-cn.enable = true;
  modules.autoclaw-intl.enable = true;
  modules.xiaohuanxiong.enable = true;
  modules.mobileclaw.enable = true;
  # `multi-instance <app> <account>`: the same apps under bubblewrap with one
  # state directory per account; see modules/nixos/base/custom/ai/agent-accounts.nix.
  # CodeBuddy account 1 accepts the canonical `multi-instance codebuddy-acp 1`
  # and the seed-once legacy `multi-instance codebuddy 1`; both use the
  # historical ~/.local/state/multi-instance/codebuddy/1 directory.
  modules.agent-accounts.enable = true;
  modules.agent-accounts.desktopAccounts = {
    workbuddy = 2;
    workbuddy-ai = 6;
    lobsterai = 2;
    trae-cn = 2;
    # trae = 6;
    zcode = 8;
    # qoder = 4;
    # qoder-ide = 4;
    qoder-cn = 2;
    # qoder-cn-ide = 2;
    autoclaw-cn = 2;
    autoclaw-intl = 4;
    xiaohuanxiong = 2;
    mobileclaw = 2;
  };
  # Group each program's launchers into one app-grid folder. Only the GNOME
  # variant has an app grid; the keys are GNOME dconf paths, so the other
  # variants have nothing to do with them.
  modules.multi-instance.gnomeAppFolders.enable = lib.mkIf config.modules.desktop.gnome-wayland.enable true;
  # Power off when NO channel to reach this device remains for 30min. The
  # offline-assessment is "do I still have any channel to connect in through",
  # so every overlay channel gets its own probe and `mode = "any"` keeps the
  # machine on while even one channel answers. All endpoints come from
  # myvars.networking.peers (easytier/zerotier/tailscale).
  # For temporary live tweaks without a rebuild use
  # `sudo auto-shutdown {disable|enable|grace|reset}`(changes reset on reboot).
  # See modules/nixos/base/custom/system/auto-shutdown/default.nix.
  modules.auto-shutdown = {
    enable = true;
    mode = "any";
    conditions = [
      # easytier: the primary and most stable channel -> probe both peers
      (pingCondition "easytier infiniti" myvars.networking.peers.infiniti.easytier)
      (pingCondition "easytier wsl-work" myvars.networking.peers.work.easytier)
      # tailscale: the android peer answers `tailscale ping` but not ICMP,
      # so probe at the tailscale layer(exit 0 on pong, non-zero on timeout)
      {
        name = "tailscale infiniti";
        command = pkgs.writeShellScript "auto-shutdown-tailscale-infiniti" ''
          exec ${pkgs.tailscale}/bin/tailscale ping -c 1 ${myvars.networking.peers.infiniti.tailscale}
        '';
      }
      # zerotier: ICMP probe of the android endpoint(passes while that device
      # is online on the zerotier network; zerotier-cli cannot map IP->node)
      (pingCondition "zerotier infiniti" myvars.networking.peers.infiniti.zerotier)
    ];
    gracePeriod = "30min";
    checkInterval = "10min";
    verbose = true;
  };
}
