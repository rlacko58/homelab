{
  config,
  lib,
  ...
}:

let
  getIp = iface: (lib.head config.networking.interfaces.${iface}.ipv4.addresses).address;
  cfg = config.services.k3s-custom;
in
{
  options.services.k3s-custom = {
    tailscaleDomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The Tailscale tailnet domain";
    };
    extraSans = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional TLS SANs";
    };
  };

  config = {
    sops.secrets.k3s_cluster_token.restartUnits = [ "k3s.service" ];

    services.k3s = {
      enable = true;
      role = "server";
      tokenFile = config.sops.secrets.k3s_cluster_token.path;

      manifests = {
        cilium-config.source = ./manifests/cilium-config.yaml;
        kube-vip.source = ./manifests/kube-vip.yaml;
      };

      extraFlags = lib.concatStringsSep " " (
        [
          "--node-ip=${getIp "data0"}"
          "--write-kubeconfig-mode=0644"
          "--tls-san=127.0.0.1"
          "--tls-san=172.10.10.10" # VIP for kube-vip
          "--tls-san=localhost"
          "--tls-san=${getIp "data0"}"
          "--tls-san=${getIp "net0"}"
          (lib.optionalString (
            cfg.tailscaleDomain != ""
          ) "--tls-san=${config.networking.hostName}.${cfg.tailscaleDomain}")
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable-kube-proxy"
          "--disable=traefik"
          "--disable=servicelb"
          "--kube-controller-manager-arg=bind-address=0.0.0.0"
          "--kube-scheduler-arg=bind-address=0.0.0.0"
          "--etcd-expose-metrics=true"
          "--node-taint=CriticalAddonsOnly=true:NoExecute"
          "--service-node-port-range=1-32767"
          "--resolv-conf=/run/systemd/resolve/resolv.conf"
        ]
        ++ (map (san: "--tls-san=${san}") cfg.extraSans)
      );
    };

    networking.firewall = {
      trustedInterfaces = [
        "cilium_host"
        "cilium_net"
      ];
      allowedTCPPorts = [
        6443 # Kubernetes API
        2379 # etcd server client API
        2380 # etcd server peer API
        9345 # kube-vip
        10250 # kubelet API
      ];
      allowedUDPPorts = [
        8472 # Cilium VXLAN
      ];
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv4.conf.default.rp_filter" = 0;
      "net.ipv4.conf.lo.rp_filter" = 0;
      "net.ipv4.conf.data0.rp_filter" = 0;
      "net.ipv4.conf.net0.rp_filter" = 0;
      "net.ipv4.conf.tailscale0.rp_filter" = 0;
    };
  };
}
