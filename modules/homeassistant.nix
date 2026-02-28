{ config, ... }:
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

  # Backup
  services.borgbackup.jobs."homeassistant" = {
    paths = [ "/var/lib/homeassistant" ];

    repo = "root@apollon.blue-powan.ts.net:/backups/homeassistant";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg_homeassistant_repo_pw.path}";
    };

    exclude = [ "/var/lib/homeassistant/backups/*" ];

    doInit = false;

    environment = {
      BORG_RSH = "ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new";
      BORG_CACHE_DIR = "/var/tmp/borg-cache";
    };

    compression = "lz4";
    startAt = "daily";

    prune.keep = {
      daily = 7;
      weekly = 4;
    };

    extraCreateArgs = [
      "--verbose"
      "--stats"
      "--list"
      "--chunker-params"
      "19,23,21,4095"
    ];
    extraArgs = "--verbose";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/homeassistant 0755 root root -"
    "d /var/tmp/borg-cache 0700 root root -"
  ];
}
