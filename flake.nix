{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-21.11;

    naersk = {
      url = github:nix-community/naersk;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    radio-conf = {
      url = github:dump-dvb/radio-conf;
    };

    data-accumulator = {
      url = github:dump-dvb/data-accumulator;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.naersk.follows = "naersk";
    };

    decode-server = {
      url = github:dump-dvb/decode-server;
    };

    dvb-api = {
      url = github:dump-dvb/dvb-api;
    };

    stops = {
      url = github:dump-dvb/stop-names;
      flake = false;
    };

    windshield = {
      url = github:dump-dvb/windshield;
    };
  };

  outputs = { self, nixpkgs, naersk, radio-conf, data-accumulator, decode-server, dvb-api, stops, windshield, ... }@inputs:
    let
      generate_system = (number:
        {
          "traffic-stop-box-${toString number}" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/traffic-stop-box/configuration.nix
              (./hosts/traffic-stop-box/hardware-configuration.nix)
              ./hosts/traffic-stop-box/configuration-dell-wyse-3040.nix
              ./modules/gnuradio.nix
              ./modules/radio_wireguard_client.nix
              ./modules/numbering.nix
              {
                nixpkgs.overlays = [ radio-conf.overlay."x86_64-linux" decode-server.overlay."x86_64-linux" ];
                dvb-dump.systemNumber = number;
                dvb-dump.stopsJson = "${stops}/stops.json";
              }
            ];
          };
        }
      );

      # increment this number if you want to add a new system
      numberOfSystems = 10;
      # list of accending system numbers
      #id_list = ((num: if num <= 0 then [ num ] else [ num ] ++ (id_list (num - 1))) (numberOfSystems - 1));
      id_list = [ 0 1 2 3 4 5 6 7 8 9 10 ];
      # list of nixos systems
      list_of_systems = builtins.map generate_system id_list;
      # attribute set of all traffic stop boxes
      stop_boxes = nixpkgs.lib.foldr (x: y: nixpkgs.lib.mergeAttrs x y) { } list_of_systems;
    in
    {
      defaultPackage."x86_64-linux" = self.nixosConfigurations.traffic-stop-box-0.config.system.build.vm;
      packages."x86_64-linux".traffic-stop-box = self.nixosConfigurations.traffic-stop-box-0.config.system.build.vm;
      packages."x86_64-linux".data-hoarder = self.nixosConfigurations.data-hoarder.config.system.build.vm;
      packages."x86_64-linux".mobile-box = self.nixosConfigurations.mobile-box.config.system.build.vm;

      nixosConfigurations = stop_boxes // {
          "mobile-box" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/traffic-stop-box/configuration.nix
              ./hosts/traffic-stop-box/hardware-configuration.nix
              ./modules/gnuradio.nix
              ./modules/radio_wireguard_client.nix
              ./modules/numbering.nix
              {
                nixpkgs.overlays = [ radio-conf.overlay."x86_64-linux" decode-server.overlay."x86_64-linux" ];
                dvb-dump.stopsJson = "${stops}/stops.json";
              }
            ];
          };
        } //
        {
          data-hoarder = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/data-hoarder/configuration.nix
              ./modules/data-accumulator.nix
              ./modules/nginx.nix
              ./modules/wireguard_server.nix
              ./modules/public_api.nix
              ./modules/map.nix
              ./modules/file_sharing.nix
              ./modules/numbering.nix
              {
                nixpkgs.overlays = [ data-accumulator.overlay."x86_64-linux" dvb-api.overlay."x86_64-linux" windshield.overlay."x86_64-linux" ];
                dvb-dump.stopsJson = "${stops}/stops.json";
              }
            ];
          };
        };

      hydraJobs = {
        data-hoarder."x86_64-linux" = self.nixosConfigurations.data-hoarder.config.system.build.toplevel;
        traffic-stop-box-0."x86_64-linux" = self.nixosConfigurations.traffic-stop-box-0.config.system.build.toplevel;
        mobile-box."x86_64-linux" = self.nixosConfigurations.mobile-box.config.system.build.sdImage;
      };
    };
}


