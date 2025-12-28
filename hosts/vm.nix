{ vars, ... }:
{
  boot.loader.grub = {
    enable = true;
    device = vars.disk.grubDevice;
  };

  fileSystems."/" = {
    device = vars.disk.rootDevice;
    fsType = "ext4";
  };

  virtualisation.vmVariant.virtualisation = {
    memorySize = 2048;
    cores = 2;
    graphics = false;
  };
}
