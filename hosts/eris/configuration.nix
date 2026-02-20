{ ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/core.nix
    # ../../modules/k3s-server.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "eris";
  system.stateVersion = "25.11";

  systemd.network.links."10-net0" = {
    matchConfig.MACAddress = "38:05:25:36:41:58";
    linkConfig.Name = "net0";
  };
  networking = {
    useDHCP = false;
    enableIPv6 = false;
    interfaces.net0.ipv4.addresses = [
      {
        address = "192.168.1.60";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";
    nameservers = [
      "1.1.1.3"
      "1.0.0.3"
    ];
  };
}
