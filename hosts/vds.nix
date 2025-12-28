{ lib, vars, ... }:
let
  staticCfg = vars.network.static;
  staticInterface = lib.genAttrs [ staticCfg.interface ] (_: {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = staticCfg.address;
        prefixLength = staticCfg.prefixLength;
      }
    ];
  });
in
{
  boot.loader.grub = {
    enable = true;
    device = vars.disk.grubDevice;
  };

  fileSystems."/" = {
    device = vars.disk.rootDevice;
    fsType = "ext4";
  };

  networking =
    {
      useDHCP = lib.mkDefault true;
    }
    // lib.optionalAttrs staticCfg.enable {
      useDHCP = false;
      defaultGateway = staticCfg.gateway;
      nameservers = staticCfg.dns;
      interfaces = staticInterface;
    };
}
