{ ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.homeassistant = {
    image = "ghcr.io/home-assistant/home-assistant:2026.2.3";
    volumes = [
      "/var/lib/homeassistant:/config"
      "/etc/localtime:/etc/localtime:ro"
    ];
    extraOptions = [
      "--network=host"
      "--privileged"
      "--device=/dev/serial/by-id/usb-Nabu_Casa_Home_Assistant_Connect_ZBT-1_7666393408d7ed11bab96d6162c613ac-if00-port0"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/homeassistant 0755 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
