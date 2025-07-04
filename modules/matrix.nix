{
  pkgs,
  lib,
  config,
  ...
}: let
  fqdn = "${config.networking.hostName}.${config.networking.domain}";
  baseUrl = "https://${fqdn}";
  clientConfig."m.homeserver".base_url = baseUrl;
  serverConfig."m.server" = "${fqdn}:443";
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON data}';
  '';
in {
  networking.firewall.allowedTCPPorts = [80 443];

  services.postgresql = {
    enable = true;
    ensureDatabases = ["matrix-synapse"];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };

  security.acme.defaults.email = "dev@choffmann.io";
  security.acme.acceptTerms = true;

  # https://nixos.org/manual/nixos/stable/index.html#module-services-matrix-synapse
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      };
      "${fqdn}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".extraConfig = ''
          return 404;
        '';
        locations."/_matrix".proxyPass = "http://[::1]:8008";
        locations."/_synapse/client".proxyPass = "http://[::1]:8008";
        locations."/_synapse/admin".proxyPass = "http://[::1]:8008";
      };
    };
  };

  services.matrix-synapse = {
    enable = true;
    settings.server_name = config.networking.domain;
    settings.public_baseurl = baseUrl;
    settings.listeners = [
      {
        port = 8008;
        bind_addresses = ["::1"];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [
          {
            names = ["client" "federation"];
            compress = true;
          }
        ];
      }
    ];
  };
}
