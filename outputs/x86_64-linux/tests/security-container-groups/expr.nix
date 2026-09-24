{ myvars, outputs, ... }:
let
  userGroups = outputs.nixosConfigurations.ai-niri.config.users.users.${myvars.username}.extraGroups;
in
{
  userHasDockerAccess = builtins.elem "docker" userGroups;
  userHasPodmanAccess = builtins.elem "podman" userGroups;
}
