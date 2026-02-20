{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/tailscale.nix
    # ../../modules/k3s-server.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;

    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets.tailscale_client_id = { };
    secrets.tailscale_client_secret = { };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "eris";
  system.stateVersion = "25.11";

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    vlans.data0 = {
      id = 100;
      interface = "net0";
    };

    interfaces = {
      net0 = {
        ipv4.addresses = [
          {
            address = "192.168.1.60";
            prefixLength = 24;
          }
        ];
        # MTU 9000 to match data0 until migrated to other node
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
    };

    defaultGateway = "192.168.1.1";
    nameservers = [
      "1.1.1.3"
      "1.0.0.3"
    ];
  };

  systemd.network.links."10-net0" = {
    matchConfig.MACAddress = "38:05:25:36:41:58";
    linkConfig.Name = "net0";
  };
}
