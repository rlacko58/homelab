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

### Flux GitOps

Declarative Kubernetes resource management with Flux v2:

- **[Flux System](k8s-manifests/flux-system/)**: Core Flux controllers (source, kustomize, helm, notification), Git repository sync, and infrastructure sync orchestration.
  - **GitRepository**: Watches this GitHub repo on `master` branch, pulls updates every 1 minute.
  - **Kustomization**: Applies manifests in order with dependency tracking and health checks.
  - **HelmRepositories**: Multiple upstream chart repos (Prometheus, VictoriaMetrics, cert-manager, ingress-nginx, CloudNative-PG, Jetstack, Emberstack).
  
- **[Infrastructure Stack](k8s-manifests/infra/)**: Production-grade K8s infrastructure deployed via Flux.
  - **[cert-manager](k8s-manifests/infra/cert-manager/)**: Automated TLS certificate management with Let's Encrypt + Cloudflare DNS01 validation for `*.lasz.io` wildcard cert.
  - **[Ingress Nginx](k8s-manifests/infra/ingress-nginx/)**: HTTP(S) ingress controller, LoadBalancer type with static IP (172.10.10.11), metrics enabled.
  - **[Monitoring Stack](k8s-manifests/infra/monitoring/)**:
    - **VictoriaMetrics Cluster** (vmstorage, vminsert, vmselect): Time-series database with 30-day retention, 16Gi PVC, HPA for vmselect.
    - **vmagent**: Prometheus-compatible scraper collecting metrics from K8s API, kubelet, cAdvisor, service endpoints, and node exporters.
    - **Node Exporter & kube-state-metrics**: Host and K8s cluster metrics.
    - **Lens Metrics Proxy**: Nginx proxy for Lens IDE to query VictoriaMetrics.
  - **[TrueNAS CSI Driver](k8s-manifests/infra/tns-csi/)**: NVMe-oF storage provisioning from TrueNAS (172.10.10.100) with encrypted API config (SOPS).
  - **[Reflector](k8s-manifests/infra/reflector/)**: Automatic secret/configmap reflection across namespaces (e.g., cert-manager TLS to ingress-nginx).
  - **[CloudNative-PG](k8s-manifests/infra/cnpg-operator/)**: PostgreSQL Kubernetes operator for HA database clusters.

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
    │   └─ kube-vip (API VIP, 6443 → 172.10.10.10)
    ├─ etcd (2379, 2380)
    ├─ Kubelet (10250)
    └─ Kernel: IP forwarding, rp_filter disabled
    
    ↓
    
[Flux Controllers] (flux-system namespace)
    ├─ source-controller: Watches Git repo (GitHub)
    ├─ kustomize-controller: Renders & applies k8s-manifests
    ├─ helm-controller: Deploys HelmReleases from repos
    └─ notification-controller: Sends alerts
    
    ↓ (deploys)
    
[Infrastructure Stack] (infra namespace)
    ├─ cert-manager → Let's Encrypt/Cloudflare → *.lasz.io cert
    │   ├── Reflector mirrors TLS secret
    │   └── ingress-nginx uses reflected secret
    ├─ ingress-nginx: HTTP(S) → services via LoadBalancer (172.10.10.11)
    ├─ Monitoring (VictoriaMetrics cluster)
    │   ├── vmagent scrapes: API, kubelet, cAdvisor, endpoints
    │   ├── vmcluster persists metrics (30d, 16Gi)
    │   └── vmselect serves Prometheus API
    │       └── lens-metrics proxy for Lens IDE
    ├─ TrueNAS CSI: Dynamic PVC provisioning via NVMe-oF
    └─ CloudNative-PG: Ready for HA PostgreSQL
```

**GitOps Flow**: Push to `master` → GitHub → Flux source-controller pulls → kustomize-controller reconciles infra `_sync/` ordering → Secrets decrypted via SOPS age keys → Resources created/updated.

**Secret Flow**: SOPS encrypts K8s secrets (Cloudflare API token, TrueNAS key) with age keys shared between GitHub Actions and eris. Flux decryption happens at reconciliation.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- SSH ed25519 keys for each host (placed in secrets).
- SOPS age key for encryption (`.sops.yaml` configured).
- GitHub secrets:
  - `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET` for Tailscale auto-auth.
  - `SSH_PRIVATE_KEY` for root SSH access to eris.
- Kubernetes secrets (auto-created by Flux):
  - `flux-user-ssh-key`: SSH key for GitHub repo access.
  - `sops-age`: Age key for decrypting SOPS secrets in K8s.

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
   - Create Flux SSH & age secrets manually:
     ```sh
     # SSH key for GitHub (one-time, from your GitHub deploy key)
     kubectl create secret generic flux-user-ssh-key \
       --from-file=identity=/path/to/github-ssh-key \
       -n flux-system
     
     # Age key for SOPS (from your .sops.yaml keys)
     kubectl create secret generic sops-age \
       --from-file=age.agekey=/path/to/age-key \
       -n flux-system
     ```
   - Rebuild:
     ```sh
     sudo nixos-rebuild switch --flake .#eris
     ```

4. **Verify**:
   - Check Tailscale: `sudo tailscale status`.
   - Check K3s: `sudo k3s kubectl get nodes`.
   - Check Cilium: `sudo k3s kubectl -n kube-system get pods -l k8s-app=cilium`.
   - Check Flux: `flux check --pre && flux get all -A`.
   - Watch Flux reconciliation: `flux logs -f`.

For the public VM, use Debian and configure manually per [hosts/vps-public-vm/README.md](hosts/vps-public-vm/README.md).

## Usage

- **Dev**: `nix develop` for a shell with `kubectl`, `fluxcd`, `sops`, `nixd`, etc.
- **Deploy**: Push to `master` and GitHub Actions runs [.github/workflows/deploy-nixos-eris.yml](.github/workflows/deploy-nixos-eris.yml) via SSH.
- **Validate**: Open a PR to trigger [.github/workflows/dry-run-nixos.yml](.github/workflows/dry-run-nixos.yml) for dry-run evaluation.
- **Secrets**: Edit with `sops k8s-manifests/infra/cert-manager/issuer/cloudflare-dns01-lasz-io-secret.yaml` (auto-decrypts age-encrypted file).
- **Rebuild Locally**: `sudo nixos-rebuild switch --flake .#eris`.
- **Check Config Diff**: `nvd diff /run/current-system ./result` after `nix build .#eris`.
- **Flux Diff**: Open a PR targeting K8s manifests—GitHub Action posts Flux diff preview.
- **Flux Reconcile**: `flux reconcile kustomization infra && flux logs -f`.
- **Check Helm Values**: `flux get helmrelease -A` and `flux export helmrelease <name> -n <ns>`.

## Why Each Component

| Component | Why |
|-----------|-----|
| **NixOS** | Declarative, reproducible, atomic updates, easy rollback. |
| **K3s** | Lightweight K8s, perfect for homelab (low resource overhead). |
| **Cilium** | Advanced networking, Hubble for observability, no dependency on kube-proxy. |
| **kube-vip** | HA for API endpoint, simple to deploy as manifest. |
| **Tailscale** | Zero-trust networking, handles NAT/firewalls, integrates wireguard cleanly. |
| **Flux** | GitOps, declarative infra in Git, automatic reconciliation, multi-app orchestration. |
| **cert-manager** | Automate TLS with Let's Encrypt, no manual cert renewal. |
| **Ingress Nginx** | Standard K8s ingress, high-performance, widely supported. |
| **VictoriaMetrics** | Lightweight Prometheus alternative, good compression, long retention on homelab hardware. |
| **TrueNAS CSI** | Leverage existing TrueNAS for K8s storage, NVMe-oF for speed. |
| **Reflector** | Reduce config duplication (e.g., single cert → many namespaces). |
| **CloudNative-PG** | Production PostgreSQL on K8s with backups, HA, rolling updates. |
| **SOPS** | Encrypt secrets in Git without external secret store (for now). |
| **GitHub Actions** | Free CI/CD, easy to trigger on push/PR, integrates with repo. |
| **Renovate** | Auto-update Nix flakes & Helm chart versions via PR. |

## File Structure

```
.
├── flake.nix                 # Flake definition, inputs/outputs
├── secrets.yaml              # SOPS-encrypted secrets (Tailscale, K3s)
├── README.md                 # This file
├── .sops.yaml                # SOPS config (age keys, encrypted files)
├── .envrc                    # direnv config (auto nix develop)
├── renovate.json             # Auto-update deps via PR
├── .github/workflows/
│   ├── deploy-nixos-eris.yml # Deploy on master push
│   ├── dry-run-nixos.yml     # Validate Nix on PR
│   └── flux-diff-on-pr.yml   # Flux diff preview on K8s PR
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
├── k8s-manifests/
│   ├── flux-system/          # Flux components & sync config
│   │   ├── gotk-components.yaml    # Flux controllers
│   │   ├── gotk-sync.yaml          # Git source + kustomization
│   │   ├── helm-repositories.yaml  # Chart repos
│   │   ├── namespaces.yaml         # K8s namespaces
│   │   ├── priority-classes.yaml   # Pod priority levels
│   │   └── kustomization.yaml      # Root kustomization
│   └── infra/
│       ├── _sync/            # Kustomizations (ordered, dependency tracking)
│       │   ├── cert-manager.yaml
│       │   ├── cnpg-operator.yaml
│       │   ├── ingress-nginx.yaml
│       │   ├── monitoring.yaml
│       │   ├── reflector.yaml
│       │   └── tns-csi.yaml
│       ├── cert-manager/     # TLS certificates & issuers
│       ├── cnpg-operator/    # PostgreSQL operator
│       ├── ingress-nginx/    # HTTP(S) ingress
│       ├── monitoring/       # VictoriaMetrics, vmagent, exporters
│       ├── reflector/        # Secret/configmap reflection
│       └── tns-csi/          # TrueNAS CSI driver
└── secrets/                  # SSH keys, age keys (not in Git)
```

## Monitoring & Observability

VictoriaMetrics stack collects metrics from:
- **Kubernetes API Server**: `kubernetes-apiservers` job
- **Kubelet**: `kubelet` job, cAdvisor metrics for container stats
- **Node Exporter**: `release-node-exporter.yaml` (9100/TCP)
- **kube-state-metrics**: K8s resource state (deployments, pods, etc.)
- **Service Endpoints**: Auto-scrape via `prometheus.io/scrape` annotations
- **Cilium**: Operator & Envoy metrics (9963, 9964/TCP)
- **vmagent itself**: Self-scraping at localhost:8429

Query via Lens IDE using the Prometheus proxy in `lens-metrics` namespace.

## TLS & Certificate Management

- **cert-manager** watches for `Certificate` CRDs and automatically:
  - Requests wildcard cert from Let's Encrypt for `*.lasz.io`
  - Uses Cloudflare DNS01 validation (requires API token in SOPS)
  - Creates/updates `lasz-io-tls` Secret in cert-manager namespace
- **Reflector** automatically mirrors the cert to `ingress-nginx` namespace
- **ingress-nginx** uses the reflected secret for HTTPS termination

Domains:
- `*.lasz.io`: Wildcard handled by cert-manager
- `k3s-api.lasz.io`: K3s API external domain (SAN in kube-vip config)

## Storage

- **TrueNAS CSI Driver** dynamically provisions NVMe-oF volumes
- Configured for `nvmeof` protocol on TrueNAS `data/k8s/nvmeof` dataset
- Default storage class: `tns-csi-nvmeof`
- PVCs automatically mounted via NVMe-over-TCP (blazing fast!)

## Dependency Tracking & Health Checks

Flux Kustomizations in `_sync/` have explicit dependencies to ensure proper ordering:
```
cert-manager-release → cert-manager-issuer → cert-manager-certs
monitoring-vmcluster → monitoring-vmagent
monitoring-vmcluster → monitoring-lens-metrics
```

Health checks ensure resources are ready before dependent ones reconcile.

## Updates & Renovate

[renovate.json](renovate.json) auto-creates PRs to:
- Update Nix flake inputs (nixpkgs, disko, sops-nix)
- Bump Helm chart versions in `values.spec.version`
- Group non-major updates together for easy automerge

Check PRs for automated dependency updates.

## Next Steps

- **Services**: Deploy apps in new `k8s-manifests/services` folder with Flux Kustomizations + HelmReleases.
- **pluto**: Migrate monitoring & services to production host, set up future redundancy.
- **Backup**: Set up proper backup solution.
- **Observability+**: Loki for logs, Grafana for dashboards.
- **GitOps Notifications**: Telegram alerts on Flux reconciliation failures.

---

For more details, see individual module comments, Flux manifest comments, or check [flake.nix](flake.nix) and [k8s-manifests/flux-system/](k8s-manifests/flux-system/).