{ lib, inputs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/tailscale.nix
    ../../modules/homeassistant.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.tailscale_client_id = { };
    secrets.tailscale_client_secret = { };
    secrets.borg_homeassistant_repo_pw = { };
  };

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "ceres";
  networking.useDHCP = false;
  networking.enableIPv6 = false;

  networking.interfaces.data0 = {
    ipv4.addresses = [
      {
        address = "172.10.10.61";
        prefixLength = 23;
      }
    ];
    mtu = 9000;
  };
  systemd.network.links."10-data0" = {
    matchConfig.MACAddress = "1a:5e:5e:ef:a8:b6";
    linkConfig.Name = "data0";
  };

  networking.defaultGateway = "172.10.10.1";
  networking.nameservers = [
    "1.1.1.3"
    "1.0.0.3"
  ];

  system.stateVersion = "25.11";

  enable-smartd = false;

  # Ensure EMMC writes are minimized
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
    RuntimeMaxFileSize=16M
  '';
  swapDevices = [ ];
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 50;
    "vm.dirty_background_ratio" = 10;
    "vm.swappiness" = 0;
  };
  nix.gc.automatic = lib.mkForce false;
  systemd.tmpfiles.rules = [ ];
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=512M"
      "noatime"
      "nosuid"
      "nodev"
      "mode=1777"
    ];
  };
  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=2048M"
      "noatime"
      "nosuid"
      "nodev"
      "mode=1777"
    ];
  };
  fileSystems."/".options = [
    "noatime"
    "nodiratime"
  ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    9100 # Prometheus Node Exporter
  ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [
      "systemd"
      "processes"
      "pressure"
    ];
    port = 9100;
  };
}
