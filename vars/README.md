# Variables

Common variables and configuration used across my NixOS and nix-darwin configurations.

## Current Structure

```
vars/
├── README.md
├── default.nix         # Main variables entry point
└── networking.nix     # Network configuration and host definitions
```

## Components

### 1. `default.nix`

Contains user information, SSH keys, and password configuration:

- User credentials (username, full name, email)
- Initial hashed password for new installations
- SSH authorized keys (main and backup sets)
- Public key references for system access

### 2. `networking.nix`

Defines:

- **Gateway settings**: Main router and proxy gateway configurations
- **DNS servers**: IPv4 and IPv6 name servers
- **Host inventory**: static LAN hosts and their interfaces; DHCP/mobile hosts (such as the macOS
  hosts) are omitted by design
- **SSH configuration**: Remote builder aliases and known hosts configuration
- **Network topology**: Physical machines, VMs, Kubernetes clusters, and SBCs
- **`devices` / `endpoints`**: virtual-network (easytier) registrations per device; `endpoints` is
  derived from `devices` and gives the plain IP per network, e.g.
  `endpoints.y9000p2025.easytier = "10.126.126.150"`
- **`services`**: the port registry - a (service x host) matrix: `hosts.<machine>` rows hold the
  enable state of the service on that machine (wired into `modules.<name>.enable`), the bind address
  (`host`, `0.0.0.0` / `127.0.0.1` - never a machine name) and the listen port(s), so any one
  machine can diverge in any of them without touching its siblings. Entries are **sorted by primary
  port ascending**; insert a new service at its port position so the next free slot stays obvious (a
  disabled row and secondary ports do not move an entry)
- **`tunnels.work`**: the `modules.port-forwarding` table for `wsl-work`, with every
  `remotePort`/`remoteHost` taken from `services` (the `idols-ai` rows) and `endpoints`

### Port registry scope

`services` only holds what is (a) managed by a NixOS module of this flake **and** (b) reachable from
outside its host (overlay/LAN/`0.0.0.0`), plus the virtual-network registrations
(`devices`/`endpoints`/`easytier.instances`). Not registered: loopback-only listeners (the dsh GUI
on `127.0.0.1:3080`, proxychains' local client ports) and services no NixOS module drives (adb, the
LAN proxies, opencode, rdp, termux sshd) - those keep literal ports where they are used.

Consumers:

- host wiring of `options.modules.<name>` (the module options are required, with no default; each
  host reads its own `hosts.<machine>` row straight from the registry - the enable state into
  `modules.<name>.enable`, the port(s) into the port options, and for sub-store the row's `host`
  into `modules.sub-store.host`. The host file names its own key once and looks rows up through it
  (`serviceHost = "wsl-work"; svc = service: myvars.networking.services.${service}.hosts.${serviceHost};`,
  so wiring reads `modules.agent2api.port = (svc "agent2api").port;`). That key is the flake host
  name and is not always the NixOS `hostName`: `wsl-work` runs with `hostName = "work"`. ssh is the
  one service without an `enable` field: its sshd enablement is base-wide in
  `modules/nixos/base/ssh.nix`)
- `tunnels.work` remote ports/hosts (every entry targets the laptop, so the `idols-ai` rows)
- the ssh_config fold (one `Port` per `Host` block: that machine's `ssh.hosts.<key>` row when it has
  one, else `ssh.defaultPort`)
- the port-catalog page, which renders the rows as-is (enable state, bind address, ports per
  machine)

## Host Categories

`networking.nix` maps each host to its LAN address and interface. The authoritative inventory is
[`../hosts/README.md`](../hosts/README.md); this file holds only the addresses.

## Usage

These variables are imported and used throughout the configuration.
