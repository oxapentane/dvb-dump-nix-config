{ pkgs, config, lib, ... }: {
  systemd = {
    services = {
      "dvb-api" = {
        enable = true;
        wantedBy = [ "multi-user.target" ];

        script = "exec ${pkgs.dvb-api}/bin/dvb-api &";

        environment = {
          "GRPC_HOST" = "127.0.0.1:50051";
          "DEFAULT_WEBSOCKET_HOST" = "127.0.0.1:9001";
          "GRAPH_FILE" = "${config.dvb-dump.graphJson}";
          "STOPS_FILE" = "${config.dvb-dump.stopsJson}";
        };

        serviceConfig = {
          Type = "forking";
          User = "dvb-api";
          Restart = "always";
        };
      };
    };
  };

  services = {
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "socket.${config.dvb-dump.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:9001/";
              proxyWebsockets = true;
            };
          };
        };
        "api.${config.dvb-dump.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:9002/";
              proxyWebsockets = true;
            };
          };
        };
      };
    };
  };

  # user accounts for systemd units
  users.users = {
    dvb-api = {
      name = "dvb-api";
      description = "public dvb api serive";
      isNormalUser = true;
      extraGroups = [ ];
    };
  };
}
