# Downstream-only just recipes, imported at the end of Justfile.
# Keep Justfile byte-identical to upstream (a tiny niri default-mode delta
# excepted): upstream additions or edits merge cleanly, and downstream
# recipes live here instead of colliding with them.

############################################################################
#
#  NixOS WSL related commands
#
#  WARNING: current do not work bcs https://github.com/casey/just/pull/2798
#
############################################################################

[linux]
wsl-work mode="switch-notify" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch wsl-work {{mode}} {{verbosity}}

[linux]
wsl mode="switch-notify" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch wsl-y9000p2025 {{mode}} {{verbosity}}

############################################################################
#
#  Nix-On-Droid related commands
#
############################################################################

droid mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nod-switch mondrian {{mode}}

############################################################################
#
#  Nix build memory guard
#
############################################################################

# Build a derivation in a user systemd scope with the client-side memory
# limits from vars/nix-build-guard.nix. Pass derivation targets only;
# `--no-link --print-build-logs` are added by the wrapper.
[linux]
[group('nix')]
build-limited *args:
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nix-build-limited {{args}}

############################################################################
#
#  NixOS Desktop related commands (downstream variants)
#
############################################################################

[linux]
[group('desktop')]
gnome-wayland mode="switch-notify" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch "ai-gnome-wayland" {{mode}} {{verbosity}}
  # nixos-switch $"(hostname)-gnome-wayland" {{mode}} {{verbosity}}

[linux]
[group('desktop')]
kde-wayland mode="switch-notify" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch "ai-kde-wayland" {{mode}} {{verbosity}}
  # nixos-switch $"(hostname)-kde-wayland" {{mode}} {{verbosity}}
