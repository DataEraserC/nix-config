{
  # Sign commits with the OpenPGP [S] subkey that both CanoKeys hold; the card's
  # touch cache covers a burst of commits. Desktop layer only, where the cards
  # are used; fork policy: docs/security-keys_downstream.md#git-commit-signing.
  programs.git = {
    signing.key = "8A24187A88B7F2B4!"; # exact [S] subkey; `!` disables GPG key re-selection
    # Not signByDefault: its tag.gpgSign turns every lightweight `git tag` into an annotated one.
    settings.commit.gpgSign = true;
    # The personal key carries no work address, so work commits stay unsigned.
    includes = [
      {
        condition = "gitdir:~/work/";
        contents.commit.gpgSign = false;
      }
    ];
  };
}
