# Homelab NixOS Setup

This is my NixOS homelab config using flakes. It runs a K3s cluster on the main server "eris", with Tailscale for networking, and Flux coming soon for full GitOps. Everything's declarative and version-controlled for easy management.

## What's Inside

Built with NixOS for reproducible infra. Here's the key stuff:

- **Nix Flakes**: Manages deps and configs for NixOS systems.
- **K3s Cluster**: Lightweight Kubernetes on "eris", with Cilium for networking and kube-vip for load balancing.
- **Tailscale**: Secure mesh networking with auto-auth.
- **Flux**: Upcoming for GitOps, deploying Kubernetes manifests from this repo.
- **Secrets**: SOPS encrypts things like Tailscale creds and K3s tokens.
- **CI/CD**: GitHub Actions for dry runs on PRs and deploys to "eris" on master pushes.
- **Hosts**:
  - `eris`: Demo main K3s server, using it to test out everything
  - `pluto`: My old host, it will be the production host once all code is ready and tested on eris.
  - `vps-public-vm`: Public VM with Nginx proxy to Tailscale ingress, Crowdsec for security.

Reusable modules:
- `core.nix`: Base setup with SSH, Nix, and packages.
- `tailscale.nix`: Tailscale service.
- `k3s-server.nix`: K3s with Cilium and kube-vip manifests.
- `manifests`: Kubernetes YAML for Cilium and kube-vip.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- SSH keys and SOPS secrets.
- GitHub secrets for Tailscale OAuth and SSH key for deploys.

## Bootstrap

To set up a new NixOS system like "eris":

1. Download the latest NixOS minimal ISO from [nixos.org](https://nixos.org/download.html).

2. Boot and install:
   - Boot from ISO.
   - Partition with Disko (see disko-config.nix).
   - Clone repo: `git clone https://github.com/your-repo/homelab.git /mnt/etc/nixos`.
   - Generate config: `nixos-generate-config --root /mnt`.
   - Install: `nixos-install --flake /mnt/etc/nixos#eris`.

3. Post-install:
   - Reboot.
   - Ensure SOPS age keys (.sops.yaml).
   - Rebuild: `sudo nixos-rebuild switch --flake .#eris`.

For the public VM, use a Debian ISO and configure Nginx/Crowdsec/tailscale. See `hosts/vps-public-vm/README.md` for details.

## Usage

- Dev: `nix develop` for `kubectl`, `sops`, etc.
- Deploy: Push to master for GitHub Actions via deploy-nixos-eris.yml.
- Validate: PRs trigger dry runs with dry-run-nixos.yml.
- Secrets: Edit secrets.yaml with `sops secrets.yaml`.

Check flake.nix for outputs or configuration.nix for details.