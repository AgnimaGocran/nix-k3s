{ lib, pkgs, vars, ... }:
{
  networking.hostName = lib.mkDefault vars.hostname;

  time.timeZone = "Europe/Brussels";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ vars.sshPublicKey ];

  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  environment.systemPackages = with pkgs; [
    kubectl
    curl
    git
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "23.11";
}
