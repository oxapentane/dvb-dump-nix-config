{ pkgs, lib, config, ... }: {
  services = {
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "files.${config.dvb-dump.domain}" = {
          enableACME = true;
          forceSSL = true;
          root = "/var/lib/data-accumulator/";
          extraConfig = ''
            autoindex on;
          '';
        };
      };
    };
    cron = {
      enable = true;
      systemCronJobs = [
        "0 0 0 * * cd /var/lib/data-accumulator/ && cp ./formatted.csv ./data/$(date +\"%d-%m-%Y\")-raw-data.csv"
      ];

    };
  };

  systemd.services.dump-csv = {
    path = with pkgs; [ influxdb gzip ];
    script = ''
      cd /tmp
      TMPFILE=$(mktemp telegrams.XXXXX.csv.gz)
      influx -precision rfc3339 -database dvbdump -execute "SELECT * FROM telegram_r_09" -format csv | gzip -c > $TMPFILE
      chmod a+r $TMPFILE

      mv $TMPFILE /var/lib/data-accumulator/data/telegrams.csv.gz
    '';
  };
  systemd.timers.dump-csv = {
    partOf = [ "dump-csv.service" ];
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "hourly";
  };
}
