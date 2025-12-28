{ lib, vars, ... }:
let
  domain = vars.domain or "";
  namespace = "status-check";
  enabled = domain != "";
in
lib.mkIf enabled {
  services.k3s.manifests."status-check" = {
    target = "status-check.yaml";
    content = [
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = { name = namespace; };
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "status-whoami";
          inherit namespace;
          labels.app = "status-check";
        };
        spec = {
          replicas = 1;
          selector.matchLabels.app = "status-check";
          template = {
            metadata.labels.app = "status-check";
            spec.containers = [
              {
                name = "whoami";
                image = "ghcr.io/traefik/whoami:v1.10.0";
                ports = [
                  {
                    containerPort = 80;
                    name = "http";
                  }
                ];
                readinessProbe.httpGet = {
                  path = "/";
                  port = "http";
                };
              }
            ];
          };
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "status-service";
          inherit namespace;
        };
        spec = {
          selector.app = "status-check";
          ports = [
            {
              name = "http";
              port = 80;
              targetPort = "http";
            }
          ];
        };
      }
      {
        apiVersion = "traefik.containo.us/v1alpha1";
        kind = "IngressRoute";
        metadata = {
          name = "status-ingress";
          inherit namespace;
        };
        spec = {
          entryPoints = [ "web" "websecure" ];
          routes = [
            {
              kind = "Rule";
              match = "Host(`" + domain + "`)";
              services = [
                {
                  name = "status-service";
                  port = 80;
                }
              ];
            }
          ];
          tls.certResolver = "letsencrypt";
        };
      }
    ];
  };
}
