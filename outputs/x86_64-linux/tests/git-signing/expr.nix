{
  myvars,
  outputs,
  ...
}:
let
  git = outputs.nixosConfigurations.ai-niri.config.home-manager.users.${myvars.username}.programs.git;
in
{
  signingKey = git.signing.key;
  commitSigning = git.settings.commit.gpgSign;
}
