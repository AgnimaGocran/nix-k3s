{ pkgs, ... }:
let
  containerdSocket = "unix:///run/k3s/containerd/containerd.sock";
in
{
  services.journald.extraConfig = ''
    SystemMaxUse=250M
    RuntimeMaxUse=250M
  '';

  systemd.services."crictl-prune" = {
    description = "Prune unused container images from the k3s containerd";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.cri-tools}/bin/crictl \
        --runtime-endpoint ${containerdSocket} \
        --image-endpoint ${containerdSocket} \
        rmi --prune
    '';
  };

  systemd.timers."crictl-prune" = {
    description = "Weekly container image garbage collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
