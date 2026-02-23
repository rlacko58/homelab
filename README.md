# Homelab Setup

This is my homelab config using Nix & Flux for a reproducible infra.

## What's Inside

### Core Infrastructure
- **Nix Flakes**: Manages all dependencies and system configurations for NixOS hosts.
- **K3s Cluster**: Lightweight Kubernetes on "eris", optimized for homelab use.
- **Tailscale**: Secure mesh networking with automatic authentication and relay support.
- **Cilium**: CNI providing networking and network policies for K3s.
- **kube-vip**: Virtual IP for Kubernetes API high availability.
- **SOPS**: Encrypts secrets (Tailscale creds, K3s tokens) at rest in version control.
- **GitHub Actions**: CI/CD for validating changes and deploying to "eris" on pushes.

### Hosts

- **eris**: Main K3s server (192.168.1.60, 172.10.10.60 on data VLAN). Intel NUC with NVMe over TCP support. Active test bed for new configs.
- **pluto**: Future production host (configured but not active yet).
- **vps-public-vm**: Debian-based public VM with Nginx TCP proxy to Tailscale ingress, Crowdsec for DDoS/brute-force protection.

### Modules

Reusable NixOS configurations:

- **[core.nix](modules/core.nix)**: Base setup across all hosts—SSH hardening, Nix settings, common packages (git, curl, htop, smartmontools), timezone/locale.
- **[tailscale.nix](modules/tailscale.nix)**: Tailscale service with automatic authentication via OAuth2. Systemd service waits for network and secrets before connecting. Advertises K8s node tags for network segmentation.
- **[k3s-server.nix](modules/k3s-server.nix)**: K3s server configuration with:
  - Cilium manifests for advanced networking (VXLAN backend, no kube-proxy).
  - kube-vip manifests for API load balancing (VIP: 172.10.10.10).
  - TLS SANs for API access via multiple interfaces, Tailscale domain, and external domains.
  - Kernel tuning for networking (IP forwarding, reverse path filtering).
  - Firewall rules for K3s services, etcd, metrics, and kubelet.
  - NVMe fabric support for remote storage.

## How Components Interact

```
Internet
    ↓
[vps-public-vm] ← Tailscale relay connection
    ↓
Tailscale Mesh Network (secure, encrypted)
    ↓
[eris K3s Server]
    ├─ Tailscale daemon (auto-auth via sops secrets)
    ├─ K3s server
    │   ├─ Cilium (VXLAN networking, 8472/UDP)
    │   └─ kube-vip (API VIP, 9345/TCP)
    ├─ etcd (2379/TCP, 2380/TCP)
    ├─ Cilium Operator & Envoy metrics (9963/TCP, 9964/TCP)
    ├─ Kubelet API (10250/TCP)
    └─ Kernel: IP forwarding, Tailscale rp_filter disabled
```

**Secret Flow**: GitHub Actions uses SOPS with age to decrypt `secrets.yaml` during deployments. Host decrypts at boot with ssh-ed25519 keys.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- SSH ed25519 keys for each host (placed in secrets).
- SOPS age key for encryption (`.sops.yaml` configured).
- GitHub secrets:
  - `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` for auto-auth.
  - SSH deploy key with access to this repo.

## Bootstrap

To set up a new NixOS host like "eris":

1. **Prepare**: Download NixOS minimal ISO.

2. **Boot & Install**:
   - Boot from ISO, switch to root.
   - Partition and format with Disko:
     ```sh
     nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- --mode disko ./hosts/eris/disko-config.nix
     ```
   - Clone repo:
     ```sh
     git clone https://github.com/rlacko/homelab.git /mnt/etc/nixos
     ```
   - Generate hardware config (updates [hosts/eris/hardware.nix](hosts/eris/hardware.nix)):
     ```sh
     nixos-generate-config --root /mnt
     ```
   - Install:
     ```sh
     nixos-install --flake /mnt/etc/nixos#eris
     ```

3. **Post-Install**:
   - Reboot into NixOS.
   - Ensure SOPS age keys are in place (`.sops.yaml` and `secrets/` directory).
   - Populate `secrets.yaml` with actual values (Tailscale OAuth, K3s token).
   - Rebuild:
     ```sh
     sudo nixos-rebuild switch --flake .#eris
     ```

4. **Verify**:
   - Check Tailscale: `sudo tailscale status`.
   - Check K3s: `sudo k3s kubectl get nodes`.
   - Check Cilium: `sudo k3s kubectl -n kube-system get pods -l k8s-app=cilium`.

For the public VM, use Debian and configure manually per [hosts/vps-public-vm/README.md](hosts/vps-public-vm/README.md).

## Usage

- **Dev**: `nix develop` for a shell with `kubectl`, `fluxcd`, `sops`, `nixd`, etc.
- **Deploy**: Push to `master` and GitHub Actions runs [.github/workflows/deploy-nixos-eris.yml](.github/workflows/deploy-nixos-eris.yml) via SSH.
- **Validate**: Open a PR to trigger [.github/workflows/dry-run-nixos.yml](.github/workflows/dry-run-nixos.yml) for dry-run evaluation.
- **Secrets**: Edit with `sops secrets.yaml` (auto-decrypts age-encrypted file).
- **Rebuild Locally**: `sudo nixos-rebuild switch --flake .#eris`.
- **Check Config Diff**: `nvd diff /run/current-system ./result` after `nix build .#eris`.

## Why Each Component

| Component | Why |
|-----------|-----|
| **NixOS** | Declarative, reproducible, atomic updates, easy rollback. |
| **K3s** | Lightweight K8s, perfect for homelab (low resource overhead). |
| **Cilium** | Advanced networking, Hubble for observability, no dependency on kube-proxy. |
| **kube-vip** | HA for API endpoint, simple to deploy as manifest. |
| **Tailscale** | Zero-trust networking, handles NAT/firewalls, integrates wireguard cleanly. |
| **SOPS** | Encrypt secrets in Git without external secret store (for now). |
| **GitHub Actions** | Free CI/CD, easy to trigger on push/PR, integrates with repo. |
| **NVMe-TCP** | Remote NVMe storage support for future distributed storage. |
| **Crowdsec + Nginx** | Public VM security—ingress to internal K8s without exposing directly. |

## File Structure

```
.
├── flake.nix                 # Flake definition, inputs/outputs
├── secrets.yaml              # SOPS-encrypted secrets
├── README.md                 # This file
├── .sops.yaml                # SOPS config (age keys, encrypted files)
├── .envrc                    # direnv config (auto nix develop)
├── renovate.json             # Auto-update deps via PR
├── .github/workflows/
│   ├── deploy-nixos-eris.yml # Deploy on master push
│   ├── dry-run-nixos.yml     # Validate on PR
│   └── flux-diff-on-pr.yml   # Flux diff preview
├── modules/
│   ├── core.nix              # Base config (SSH, Nix, packages)
│   ├── tailscale.nix         # Tailscale service + auto-auth
│   ├── k3s-server.nix        # K3s + Cilium + kube-vip
│   └── manifests/            # K3s manifests (cilium, kube-vip)
├── hosts/
│   ├── eris/
│   │   ├── configuration.nix # Host-specific config
│   │   ├── hardware.nix      # Auto-generated hardware config
│   │   └── disko-config.nix  # Disk layout for installation
│   ├── pluto/                # Future production host
│   └── vps-public-vm/        # Public relay VM config
├── k8s-manifests/            # Flux GitOps manifests (coming soon)
└── secrets/                  # SSH keys, age keys (not in Git)
```

## Next Steps

- **Flux**: Deploy K8s manifests from [k8s-manifests/](k8s-manifests/) via GitOps.
- **pluto**: Migrate to production, set up redundancy.
- **Distributed Storage**: NVMe-TCP for multi-node storage.
- **Observability**: Prometheus, Loki, Grafana stack.

---

For more details, see individual module comments or check [flake.nix](flake.nix).