{
  config,
  pkgs,
  mylib,
  nur-DataEraserC,
  ...
}:
{
  # Work-specific opencode config, independent from idols-ai's shared
  # `home/base/gui/ai/opencode.json`. Kept as its own file so it can diverge.
  xdg.configFile."opencode/opencode.json" = {
    source = mylib.mklinkRelativeToRoot config "hosts/wsl-work/opencode.json";
  };

  # modules.desktop = {
  #   hyprland = {
  #     nvidia = true;
  #     settings = {
  #       # Configure your Display resolution, offset, scale and Monitors here, use `hyprctl monitors` to get the info.
  #       #   highres:      get the best possible resolution
  #       #   auto:         position automatically
  #       #   1.5:          scale to 1.5 times
  #       #   bitdepth,10:  enable 10 bit support
  #       monitor = "eDP-1,2560x1600@60,0x0,1";
  #     };
  #   };
  # };
  # modules.editors.emacs = {
  #   enable = true;
  # };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
          ForwardAgent yes
          IdentityFile ~/.ssh/id_ed25519
          IdentitiesOnly yes

      Host github.com
          IdentityFile ~/.ssh/id_ed25519
          # Specifies that ssh should only use the identity file explicitly configured above
          # required to prevent sending default identity files first.
          IdentitiesOnly yes

      Host zerotier_devices
        HostName 10.147.20.*
        MACs hmac-sha1,hmac-sha1-96,hmac-sha2-256,hmac-sha2-512,hmac-md5
    '';
  };
  home.stateVersion = "26.05";
  home.packages = [
    # nur-DataEraserC.packages.${pkgs.system}.llqqnt
    # nur-DataEraserC.packages.${pkgs.system}.bqqnt
  ];

  # Pi Coding Agent, configured independently from idols-ai (which uses the
  # shared `home/base/gui/ai/pi-coding-agent.nix`). Managed by the official
  # home-manager module, with a newer `pi` than nixpkgs ships (0.80.3 too old
  # for extensions requiring pi >= 0.81.0, e.g. pi-free 2.4.4). We build
  # 0.84.1 from the upstream source tree via the `pi-coding-agent-unstable`
  # overlay.
  programs.pi-coding-agent = {
    enable = false;

    package = pkgs.pi-coding-agent;

    # Extra packages available to pi on PATH (needed by some pi-installed
    # packages, e.g. npm packages that invoke node/bun).
    extraPackages = [ pkgs.nodejs ];

    # AgentRouter providers, both API shapes. Key from `$AGENTROUTER_API_KEY`.
    # - `agentrouter-openai`: OpenAI-compatible, all models (gpt-5.6-sol openai-only)
    # - `agentrouter-anthropic`: Anthropic Messages
    models = {
      providers = {
        agentrouter-openai = {
          baseUrl = "https://ps.air-outer.com/v1";
          api = "openai-completions";
          apiKey = "$AGENTROUTER_API_KEY";
          models = [
            {
              id = "gpt-5.6-sol";
              name = "gpt-5.6-sol";
            }
            {
              id = "gpt-6-astra";
              name = "gpt-6-astra";
            }
            {
              id = "claude-opus-4-8";
              name = "claude-opus-4-8";
            }
            {
              id = "claude-opus-5";
              name = "claude-opus-5";
            }
            {
              id = "deepseek-v4-flash";
              name = "deepseek-v4-flash";
            }
            {
              id = "glm-5.3";
              name = "glm-5.3";
            }
          ];
        };
        agentrouter-anthropic = {
          baseUrl = "https://ps.air-outer.com";
          api = "anthropic-messages";
          apiKey = "$AGENTROUTER_API_KEY";
          models = [
            {
              id = "claude-opus-4-8";
              name = "claude-opus-4-8";
            }
            {
              id = "claude-opus-5";
              name = "claude-opus-5";
            }
            {
              id = "deepseek-v4-flash";
              name = "deepseek-v4-flash";
            }
            {
              id = "glm-5.3";
              name = "glm-5.3";
            }
          ];
        };
        # Local CLIProxyAPI endpoint (OpenAI-compatible): this host's own
        # cliproxyapi on port 1105 - not the 31105 tunnel to idols-ai - gated by
        # `modules.cliproxyapi.enable`. Key from the `$CLIPROXYAPI_API_KEY` env var.
        cliproxyapi = {
          baseUrl = "http://localhost:1105/v1";
          api = "openai-completions";
          apiKey = "$CLIPROXYAPI_API_KEY";
          models = [
            {
              id = "AgentRouter1/claude-opus-4-8";
              name = "AgentRouter1/claude-opus-4-8";
            }
            {
              id = "AgentRouter1/claude-opus-5";
              name = "AgentRouter1/claude-opus-5";
            }
            {
              id = "AgentRouter1/deepseek-v4-flash";
              name = "AgentRouter1/deepseek-v4-flash";
            }
            {
              id = "AgentRouter1/glm-5.3";
              name = "AgentRouter1/glm-5.3";
            }
            {
              id = "AgentRouter1/gpt-5.6-sol";
              name = "AgentRouter1/gpt-5.6-sol";
            }
            {
              id = "AgentRouter1/gpt-6-astra";
              name = "AgentRouter1/gpt-6-astra";
            }
            {
              id = "AgentRouter2/claude-opus-4-8";
              name = "AgentRouter2/claude-opus-4-8";
            }
            {
              id = "AgentRouter2/claude-opus-5";
              name = "AgentRouter2/claude-opus-5";
            }
            {
              id = "AgentRouter2/deepseek-v4-flash";
              name = "AgentRouter2/deepseek-v4-flash";
            }
            {
              id = "AgentRouter2/glm-5.3";
              name = "AgentRouter2/glm-5.3";
            }
            {
              id = "AgentRouter2/gpt-5.6-sol";
              name = "AgentRouter2/gpt-5.6-sol";
            }
            {
              id = "AgentRouter2/gpt-6-astra";
              name = "AgentRouter2/gpt-6-astra";
            }
          ];
        };
      };
    };

    keybindings = { };

    settings = { };
  };
}
