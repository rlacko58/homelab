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
  };

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "ceres";
  networking.useDHCP = false;
  networking.enableIPv6 = false;

  networking.interfaces.net0 = {
    ipv4.addresses = [
      {
        address = "192.168.1.61";
        prefixLength = 24;
      }
    ];
  };
  systemd.network.links."10-net0" = {
    matchConfig.MACAddress = "1a:5e:5e:ef:a8:b6";
    linkConfig.Name = "net0";
  };

  networking.defaultGateway = "192.168.1.1";
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
  swapDevices = [];
  boot.kernel.sysctl = {
    "vm.dirty_ratio" = 50;
    "vm.dirty_background_ratio" = 10;
    "vm.swappiness" = 0;
  };
  nix.gc.automatic = lib.mkForce false;
  systemd.tmpfiles.rules = [];
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=512M" "noatime" "nosuid" "nodev" "mode=1777" ];
  };
  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2048M" "noatime" "nosuid" "nodev" "mode=1777" ];
  };
  fileSystems."/".options = [ "noatime" "nodiratime" ];

  networking.firewall.enable = true;
}
