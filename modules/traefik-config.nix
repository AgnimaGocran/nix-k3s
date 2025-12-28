{ lib, vars, ... }:
let
  useStaging = vars.acme.useStaging or false;
  stagingEndpoint = "https://acme-staging-v02.api.letsencrypt.org/directory";
  certificatesResolver = {
    certificatesResolvers.letsencrypt.acme =
      {
        email = vars.leEmail;
        storage = "/data/acme.json";
        httpChallenge.entryPoint = "web";
      }
      // lib.optionalAttrs useStaging { caServer = stagingEndpoint; };
  };
  persistenceSpec = {
    persistence = {
      enabled = true;
      storageClass = "local-path";
      accessMode = "ReadWriteOnce";
      size = "256Mi";
      path = "/data";
    };
  };
  logSpec = {
    logs = {
      general.level = "WARN";
      access.enabled = false;
    };
  };
  dashboardSpec = {
    ingressRoute.dashboard.enabled = false;
  };
  values = lib.foldl' lib.recursiveUpdate { } [
    certificatesResolver
    persistenceSpec
    logSpec
    dashboardSpec
  ];
in
{
  services.k3s.manifests."traefik-helm-config" = {
    target = "traefik-helm-config.yaml";
    content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChartConfig";
      metadata = {
        name = "traefik";
        namespace = "kube-system";
      };
      spec.valuesContent = lib.generators.toYAML { } values;
    };
  };
}
