{
  description = "Single-node k3s on NixOS with built-in Traefik";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      getEnvOr =
        name: fallback:
        let
          value = builtins.getEnv name;
        in
        if value != "" then value else fallback;

      hostVars = {
        vm = {
          hostname = "k3s-vm";
          publicIP = "127.0.0.1";
          domain = "";
          leEmail = getEnvOr "NIX_K3S_LE_EMAIL" "LE_EMAIL";
          sshPublicKey = getEnvOr "NIX_K3S_SSH_KEY" "SSH_PUBLIC_KEY";
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
          hostname = getEnvOr "NIX_K3S_HOSTNAME" "HOSTNAME";
          publicIP = getEnvOr "NIX_K3S_PUBLIC_IP" "PUBLIC_IP";
          domain = getEnvOr "NIX_K3S_DOMAIN" "";
          leEmail = getEnvOr "NIX_K3S_LE_EMAIL" "LE_EMAIL";
          sshPublicKey = getEnvOr "NIX_K3S_SSH_KEY" "SSH_PUBLIC_KEY";
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
              address = getEnvOr "NIX_K3S_PUBLIC_IP" "PUBLIC_IP";
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
        ./modules/status-ingress.nix
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
