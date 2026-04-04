{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/tailscale.nix
    ../../modules/k3s-server.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.tailscale_client_id = { };
    secrets.tailscale_client_secret = { };
    secrets.k3s_cluster_token = { };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "eris";
  networking.useDHCP = false;
  networking.enableIPv6 = false;
  
  networking.vlans.data0 = {
    id = 100;
    interface = "net0";
  };

  networking.vlans.vpn0 = {
    id = 50;
    interface = "net0";
  };

  networking.interfaces = {
    net0 = {
      ipv4.addresses = [
        {
          address = "192.168.1.60";
          prefixLength = 24;
        }
      ];
      mtu = 9000;
    };

    data0 = {
      ipv4.addresses = [
        {
          address = "172.10.10.60";
          prefixLength = 23;
        }
      ];
      mtu = 9000;
    };

    vpn0 = {
      mtu = 1320;
    };
  };

  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [
    "1.1.1.3"
    "1.0.0.3"
  ];

  system.stateVersion = "25.11";

  services.resolved.enable = true;

  systemd.network.links."10-net0" = {
    matchConfig.MACAddress = "38:05:25:36:41:58";
    linkConfig.Name = "net0";
    linkConfig.MTUBytes = 9000;
  };

  services.k3s-custom = {
    tailscaleDomain = "blue-powan.ts.net";
    extraSans = [
      "k3s-api.lasz.io"
    ];
  };

  enable-smartd = true;
}
