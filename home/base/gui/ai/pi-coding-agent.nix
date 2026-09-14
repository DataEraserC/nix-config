{
  pkgs,
  ...
}:
{
  # Pi Coding Agent managed by the official home-manager module, but with a
  # newer `pi` than nixpkgs currently ships (nixpkgs = 0.80.3, too old for
  # extensions requiring pi >= 0.81.0, e.g. pi-free 2.4.4). We build 0.84.1
  # from the upstream source tree via the `pi-coding-agent-unstable` overlay
  # (no new nixpkgs input).
  programs.pi-coding-agent = {
    enable = true;

    package = pkgs.pi-coding-agent;

    # Extra packages available to pi on PATH (needed by some pi-installed
    # packages, e.g. npm packages that invoke node/bun).
    extraPackages = [ pkgs.nodejs ];

    # AgentRouter providers, both API shapes (OpenAI-compatible and Anthropic
    # Messages). The API key is read from the `$AGENTROUTER_API_KEY` env var.
    # - `agentrouter-openai`: OpenAI-compatible, all models (gpt-5.6-sol is openai-only)
    # - `agentrouter-anthropic`: Anthropic Messages, the models that support it
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
        # Local CLIProxyAPI endpoint (OpenAI-compatible). The API key is read
        # from the `$CLIPROXYAPI_API_KEY` env var.
        cliproxyapi = {
          baseUrl = "http://localhost:8317/v1";
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
