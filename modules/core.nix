{ pkgs, ... }:
{

  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpH+TNAwcmxYc5cVctH04wUU83Pba6s/AkKXOnhDn+m"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMQRgOedz/e462tl8VrOye+LqgbCTjyyyrsHDVPGSCZf github-action-ci"
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    iotop
    usbutils
    pciutils
    fastfetch
    smartmontools
  ];

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.bash.completion.enable = true;
  services.smartd.enable = true;
}
