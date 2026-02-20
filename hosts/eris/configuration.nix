{ ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/k3s-server.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "eris";
  system.stateVersion = "25.11";
}
