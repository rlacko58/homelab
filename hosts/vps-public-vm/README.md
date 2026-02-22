# Public VM in VPS

This VM exposes a Tailscale relay that exposes the Homelab's Ingress nginx service to the public internet.
To achieve this, there is an Nginx instance that acts as a TCP Proxy to the Tailscale endpoint. Also there is a crowdsec agent configured to provide some security to the public endpoint.

[Nginx Config](./nginx.conf)  
[Crowdsec config to parse nginx stream logs](./acquis.yaml)  
[Crowdsec config to parse hostnames properly for Crowdsec](./fix-nginx-stream-sni.yaml)
