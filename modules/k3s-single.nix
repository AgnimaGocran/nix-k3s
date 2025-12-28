{ lib, pkgs, config, ... }:
let
  cfg = config.services.k3s;
  kubeletArgs = [
    "image-gc-high-threshold=70"
    "image-gc-low-threshold=60"
    "eviction-hard=memory.available<200Mi,nodefs.available<10%,imagefs.available<10%"
    "max-pods=40"
  ];
  manifestDir = "/var/lib/rancher/k3s/server/manifests";
  manifestFormat = pkgs.formats.yaml { };
  mkManifestTarget =
    name:
    if lib.hasSuffix ".yaml" name || lib.hasSuffix ".yml" name then name else "${name}.yaml";
  manifestModule = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this manifest should be rendered.";
        };

        target = lib.mkOption {
          type = lib.types.nullOr lib.types.nonEmptyStr;
          default = null;
          description = ''
            Override for the manifest file name. Defaults to "${name}.yaml".
          '';
        };

        source = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to an existing YAML manifest.";
        };

        content = lib.mkOption {
          type = with lib.types; nullOr (either attrs (listOf attrs));
          default = null;
          description = "Manifest content expressed as Nix.";
        };
      };
    }
  );
  enabledManifests = lib.filterAttrs (_: manifest: manifest.enable) cfg.manifests;
  manifestEntries =
    lib.mapAttrsToList
      (
        name: manifest:
        let
          targetName = mkManifestTarget (manifest.target or name);
          sourcePath =
            if manifest.source != null then
              manifest.source
            else if manifest.content != null then
              manifestFormat.generate "k3s-manifest-${name}" manifest.content
            else
              throw "services.k3s.manifests.${name}: either `source` or `content` must be set";
        in
        {
          inherit targetName sourcePath;
        }
      )
      enabledManifests;
in
{
  options.services.k3s.manifests = lib.mkOption {
    type = lib.types.attrsOf manifestModule;
    default = { };
    description = "Auto-deployed manifests placed into k3s' manifests directory.";
  };

  config = lib.mkMerge [
    {
      services.k3s = {
        enable = true;
        role = "server";
        extraFlags = lib.concatStringsSep " " (
          [
            "--disable=metrics-server"
            "--disable=servicelb"
          ]
          ++ map (arg: "--kubelet-arg=${arg}") kubeletArgs
        );
      };
    }

    (lib.mkIf (cfg.enable && cfg.role == "server" && manifestEntries != [ ]) {
      systemd.tmpfiles.rules = [
        "d ${manifestDir} 0755 root root - -"
      ];

      system.activationScripts.k3s-manifests = lib.mkAfter (
        lib.concatStringsSep "\n" (
          [
            ''
              mkdir -p ${manifestDir}
            ''
          ]
          ++ map
            (
              entry: ''
                ln -sfn ${entry.sourcePath} ${manifestDir}/${entry.targetName}
              ''
            )
            manifestEntries
        )
      );
    })
  ];
}
