{ pkgs, ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s;
    extraFlags = [
      "--disable=traefik"
      "--disable=servicelb"
      "--flannel-backend=host-gw"
    ];
  };

  networking.firewall.allowedTCPPorts = [
    6443
    2379
    2380
  ];
}
