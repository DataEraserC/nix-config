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

Comprehensive network configuration including:

- **Gateway settings**: Main router and proxy gateway configurations
- **DNS servers**: IPv4 and IPv6 name servers
- **Host inventory**: Complete mapping of all hosts with their network interfaces and IP addresses
- **SSH configuration**: Remote builder aliases and known hosts configuration
- **Network topology**: Physical machines, VMs, Kubernetes clusters, and SBCs
- **`devices` / `endpoints`**: virtual-network (easytier) registrations per device; `endpoints` is
  derived from `devices` and gives the plain IP per network, e.g.
  `endpoints.y9000p2025.easytier = "10.126.126.150"`
- **`services`**: the port registry - a (service x host) matrix: `hosts.<machine>` rows hold the
  bind address (`host`, `0.0.0.0` / `127.0.0.1` - never a machine name), the listen port(s) and the
  service-wide `enablePath` of the NixOS option that turns it on, so any one machine can diverge
  without touching its siblings
- **`tunnels.work`**: the `modules.port-forwarding` table for `wsl-work`, with every
  `remotePort`/`remoteHost` taken from `services` (the `idols-ai` rows) and `endpoints`

### Port registry scope

`services` only holds what is (a) managed by a NixOS module of this flake **and** (b) reachable from
outside its host (overlay/LAN/`0.0.0.0`), plus the virtual-network registrations
(`devices`/`endpoints`/`easytier.instances`). Not registered: loopback-only listeners (the dsh GUI
on `127.0.0.1:9900`, proxychains' local client ports) and services no NixOS module drives (adb, the
LAN proxies, opencode, rdp, termux sshd) - those keep literal ports where they are used.

Consumers:

- host wiring of `options.modules.<name>` (the module options are required, with no default; each
  host reads its own `hosts.<machine>` row straight from the registry, next to its `enable` line.
  The row's `host` is the bind address consumed directly by `modules.sub-store.host`)
- `tunnels.work` remote ports/hosts (every entry targets the laptop, so the `idols-ai` rows)
- the ssh_config fold (one `Port` per `Host` block: that machine's `ssh.hosts.<key>` row when it has
  one, else `ssh.defaultPort`)
- the port-catalog page, which also reads `enablePath` for enablement

## Host Categories

The networking configuration covers:

- **Physical machines**: Desktop PCs, Apple Silicon systems, SBCs
- **Virtual machines**: KubeVirt guests, K3s nodes
- **Kubernetes clusters**: Production and testing environments
- **Network infrastructure**: Routers, gateways, and DNS configuration

## Usage

These variables are imported and used throughout the configuration to ensure consistency across all
hosts and maintain centralized network and security settings.
