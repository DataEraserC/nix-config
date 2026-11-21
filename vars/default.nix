{ lib }:
let
  # CanoKey resident SSH keys: the only user keys, and the only keys pam_rssh
  # accepts for sudo on servers through the forwarded agent
  # (modules/nixos/server/ssh-agent-sudo.nix).
  canokeySshKeys = [
    # canokey-tea (main)
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINuvSs4skjxNCTvN5k8rihUXOCst/XChw37aDeOmz+vvAAAAEHNzaDpyeWFuNHlpbi10ZWE= ryan@canokey-tea"
    # canokey-moe (backup)
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEZKUA4pNWvXKCpPQZHgctlR6O/71QirBQNt2RC5QsdfAAAAEHNzaDpyeWFuNHlpbi1tb2U= ryan@canokey-moe"
  ];
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
  # Public Keys that can be used to login to all my PCs, Macbooks, and servers.
  #
  # Since its authority is so large, we must strengthen its security:
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
  # CanoKey U2F registrations for sudo (modules/nixos/desktop/canokey.nix).
  # Key handles and public keys only, so they are safe to commit.
  canokeyU2fKeys = [
    # canokey-tea (main)
    "1pS52FIPHfevn97Hiz5+OOFe0OaPBPqIrsD0r/mC/YIAAdEYDZIbm8kTBUGA49wXW0ZvSpF9VNYh2w84Xz9nAIAW////+Q==,LkVavaZRhu8nHhIj1r2N78BwOlU32Y/AAGkekzn5DLQCztnMs4uslIAvzzaNNCpaDu49xwZm4TqPBDKg0IuIlA==,es256,+presence"
    # canokey-moe (backup)
    "dxdeYeJTx40VhgPll05COx1Vn3WRKuXNgtHCTpTSyq0AAdEYDZIbm8kTBUGA49wXW0ZvSpF9VNYh2w84Xz9nAIAW////+Q==,cpBHKCdambMTGau3+eXVyv4JWQK7ZQ+8AbRt0EevCL0DeftDdXX6aatHSpbiXAhjip3R8pfeXi6GTW67YpdCPw==,es256,+presence"
  ];
  secondaryAuthorizedKeys = [
    # the backup ssh keys for disaster recovery
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMzYT0Fpcp681eHY5FJV2G8Mve53iX3hMOLGbVvfL+TF ryan@romantic"
  ];
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
