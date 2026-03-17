{ pkgs, config, lib, ... }:
{
  options = {
    enable-smartd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable smartd daemon for SMART monitoring";
    };
  };

  config = {
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
      borgbackup
      ethtool
    ] ++ (if config.enable-smartd then [ smartmontools ] else []);

    time.timeZone = "UTC";
    services.timesyncd.enable = true;
    i18n.defaultLocale = "en_US.UTF-8";

    programs.bash.completion.enable = true;
    services.smartd.enable = config.enable-smartd;
  };
}
