{
  config,
  pkgs,
  ...
}:

{
  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--hostname=${config.networking.hostName}"
      "--accept-dns=true"
    ];
    useRoutingFeatures = "server";
  };

  networking.firewall.allowedUDPPorts = [ 41641 ];

  environment.systemPackages = [ pkgs.tailscale ];

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [
      "network-online.target"
      "tailscaled.service"
      "sops-install-secrets.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "sops-install-secrets.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = ''
      # Check if we are already online with a 100.x.x.x IP
      # Use timeout to prevent hanging if the daemon is unresponsive
      ONLINE_COUNT=$(${pkgs.coreutils}/bin/timeout 20 ${pkgs.tailscale}/bin/tailscale status --self=true --peers=false | grep 100 | grep -v offline | wc -l)

      if [ "$ONLINE_COUNT" -ne 1 ]; then
        echo "Tailscale is not online. Attempting to authenticate..."
        sleep 2
        
        ${pkgs.tailscale}/bin/tailscale up \
          --client-id="$(cat ${config.sops.secrets.tailscale_client_id.path})" \
          --client-secret="file:${config.sops.secrets.tailscale_client_secret.path}" \
          --hostname=${config.networking.hostName} \
          --advertise-tags=tag:k8s-node \
          --accept-dns=true
      else
        echo "Tailscale is already online. Skipping authentication."
      fi
    '';
  };
}
