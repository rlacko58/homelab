{ pkgs, inputs, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/tailscale.nix
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

  networking.interfaces.end0 = {
    ipv4.addresses = [
      {
        address = "192.168.1.61";
        prefixLength = 24;
      }
    ];
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
}
