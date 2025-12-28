{
  description = "Single-node k3s on NixOS with built-in Traefik";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      hostVars = {
        vm = {
          hostname = "k3s-vm";
          publicIP = "127.0.0.1";
          domain = "vm.local";
          leEmail = "LE_EMAIL";
          sshPublicKey = "SSH_PUBLIC_KEY";
          disk = {
            rootDevice = "/dev/disk/by-label/nixos";
            grubDevice = "/dev/vda";
          };
          acme = {
            useStaging = true;
          };
          network = {
            static = {
              enable = false;
              interface = "eth0";
              address = "127.0.0.1";
              prefixLength = 24;
              gateway = "GATEWAY";
              dns = [ "1.1.1.1" "8.8.4.4" ];
            };
          };
        };

        vds = {
          hostname = "HOSTNAME";
          publicIP = "PUBLIC_IP";
          domain = "DOMAIN";
          leEmail = "LE_EMAIL";
          sshPublicKey = "SSH_PUBLIC_KEY";
          disk = {
            rootDevice = "/dev/disk/by-label/nixos";
            grubDevice = "/dev/vda";
          };
          acme = {
            useStaging = false;
          };
          network = {
            static = {
              enable = false;
              interface = "ens3";
              address = "PUBLIC_IP";
              prefixLength = 24;
              gateway = "GATEWAY";
              dns = [ "1.1.1.1" "8.8.8.8" ];
            };
          };
        };
      };

      commonModules = [
        ./modules/base.nix
        ./modules/k3s-single.nix
        ./modules/traefik-config.nix
        ./modules/maintenance.nix
      ];

      hosts = {
        vm = ./hosts/vm.nix;
        vds = ./hosts/vds.nix;
      };

      mkHost = name:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit lib;
            vars = hostVars.${name};
          };
          modules = commonModules ++ [ hosts.${name} ];
        };
    in
    {
      nixosConfigurations = lib.mapAttrs (name: _: mkHost name) hosts;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
