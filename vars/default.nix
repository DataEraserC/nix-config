{ lib }:
let
  # The fork owns no CanoKey, so upstream's resident FIDO2 SSH keys are empty.
  # pam_rssh (modules/nixos/server/ssh-agent-sudo.nix) then trusts no key, so
  # sudo over SSH falls back to the password.
  canokeySshKeys = [ ];
in
{
  inherit canokeySshKeys;
  username = "nixos";
  userfullname = "DataEraserC";
  useremail = "102341238+DataEraserC@users.noreply.github.com";
  networking =
    let
      base = import ./networking.nix { inherit lib; };
    in
    lib.recursiveUpdate base (
      import ./networking-downstream.nix {
        inherit lib;
        upstream = base;
      }
    );
  ports = import ./ports.nix;
  # Generated using: mkpasswd -m yescrypt --rounds=11
  # Password: long, strong random string (full charset)
  # Rotation policy: changed annually
  # Purpose: system login password only
  # https://man.archlinux.org/man/crypt.5.en
  initialHashedPassword = "$7$CU..../....lO1U0fsl954fC3porcCY41$OXiwbYrYuY4Z3KSFQ6IM04D9yFBExkENIewhjyTqN7C";
  hashedPassword = "$7$CU..../....lO1U0fsl954fC3porcCY41$OXiwbYrYuY4Z3KSFQ6IM04D9yFBExkENIewhjyTqN7C";
  # Downstream's own public keys, the only ones authorized on every host.
  # The fork owns no CanoKey: a passphrase-protected ed25519 key,
  # ~/.ssh/idols-ai_id_ed25519, is the primary identity on every host (with
  # ~/.ssh/idols-ai_id_rsa as its RSA sibling), and the rest are the fork's
  # other devices.
  #
  # Upstream's per-key hygiene still applies:
  # 1. The corresponding private key must be:
  #    1. Generated locally on every trusted client via:
  #      ```bash
  #      # KDF: bcrypt with 256 rounds, takes 2s on Apple M2):
  #      # Passphrase: digits + letters + symbols, 12+ chars
  #      ssh-keygen -t ed25519 -a 256 -C "ryan@xxx" -f ~/.ssh/xxx
  #      ```
  #    2. Never leave the device and never sent over the network.
  # 2. Or just use hardware security keys like Yubikey/CanoKey.
  mainSshAuthorizedKeys = [
    # The main ssh keys for daily usage
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBiYaQw5Zd3zph4ESSmzTeThQs4mUvQl6VmAgwhFQeIj nix-on-droid@pstar"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIESZxsPpUfvzrLVVu7O1QYnUvSKWG4U6Fcv3kdxiLQTg termux@pstar"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKycQztUbwaCQnvF6wiQz+WukpAXbkubMMMp4VUtwt/ nix-on-droid@mondrian"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBPciOhklQslFUU2Y+ARt+HvBLLScjQ+c+3S2ZX9NGOK termux@mondrian"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII7NyZi1fs1EubesSvFA16UI6E3dut1XL+6F4PYqIJZ7 termux@infiniti"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZ5jg4mJdPLLwQqY5DFJwSAaQtTO6UFoPW5Z18pZroe nix-on-droid@fily_pad_f12"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBO0+WOKwK9EcRj2Bcdt/VpiB9MvZYqk4JKxlcQElskx nixos@idols-ai"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOa/B+wRm8FtHaYuQ9hNQy8FL91FVjF5hLGk4FoCY9Ix ec@DESKTOP-BOTVVJ6"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFak7BMP5b8HDe63AfaR2FmwVUgrQyg5+Uqiqd+/Jj3q openpgp:0x8B7537BE"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFGcZXWoZPVMpf2dx6a8Kw3UsTSr2Ba5ZruCER+FwNv2 braxtonj\\futang@XA-7GjSQ81EiOf4"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPdiLAS0Gwc1FIDVs5gyp0fQyJZm5KRXjR/oPZ6cezfL nixos@work"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGLeL1APZhRXbWFBoemc9deWf6s6tfmp3H/S4/D71fIA root@wsl-work"
  ];
  # Upstream's CanoKey U2F registrations, emptied downstream along with the
  # SSH keys above.
  canokeyU2fKeys = [ ];
  # Upstream's `ryan@romantic` key is not ours, and the fork keeps no separate
  # recovery identity: ~/.ssh/idols-ai_id_ed25519 covers every host.
  secondaryAuthorizedKeys = [ ];
  # The SSH host keys of the machines whose nix-daemons build through aquamarine
  # (modules/nixos/base/remote-builders.nix).
  remoteBuilderClientKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINHZtzeaQyXwuRMLzoOAuTu8P9bu5yc5MBwo5LI3iWBV root@ai"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDkbOwOeuAem8BKbyTDliRiTfHVAFdiVpAKh1bhs2s0 root@shoukei"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSSw4Oa8CaAeYXq2+O/SHHICaoUTFTGYjW5R9MzZ9Nj root@shoryu"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4Po3tzTPVKEE5fAk4RQfhTvA4h+AurnkEiM7RYdND9 root@shushou"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEs8b3CmxM+utXZVKvJBssXBupBXvvzjHP40HcY7PSyZ root@youko"
  ];
}
