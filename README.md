# nix-k3s

Single-node k3s cluster on top of NixOS with the built-in Traefik ingress controller configured for persistent ACME certificates and low-resource defaults.

## Input variables

Edit `hostVars` inside `flake.nix` before deploying:

- `HOSTNAME` – desired hostname for the VDS node.
- `PUBLIC_IP` – server IPv4 address (also used for optional static networking).
- `DOMAIN` – DNS name that should resolve to `PUBLIC_IP` for ingress testing.
- `LE_EMAIL` – e-mail passed to Let’s Encrypt/ACME.
- `SSH_PUBLIC_KEY` – root’s authorized key. The same key is reused by the local VM by default.
- Optional static networking: set `hostVars.vds.network.static.enable = true` and adjust `interface`, `prefixLength`, `gateway`, and `dns` if DHCP is not available on the VDS.
- Disk layout placeholders: adjust `hostVars.*.disk.rootDevice` and `.grubDevice` to match the actual block devices that should hold `/` and the bootloader target on both the VM image and the VDS.

## A) Local VM smoke test

1. Build and start the VM:
   ```bash
   nix build .#nixosConfigurations.vm.config.system.build.vm
   ./result/bin/run-nixos-vm
   ```
2. Inside the VM (or via forwarded SSH), check that k3s is running and the cluster is healthy:
   ```bash
   sudo systemctl status k3s
   kubectl get nodes -o wide
   kubectl get pods -A
   ```
   The k3s service must be `active (running)` and Traefik should appear as a running pod in the `kube-system` namespace. ACME uses the Let’s Encrypt staging endpoint in the VM profile so no real certificates are requested.

## B) Installing NixOS on the VDS via nixos-anywhere

1. Ensure the fresh VDS is reachable over SSH (temporary Ubuntu/Debian image is fine) and that root login is allowed (either as root or via `sudo`).
2. Run nixos-anywhere from the workstation; this streams the fully built system closure to the server:
   ```bash
   nix run github:nix-community/nixos-anywhere -- --flake .#vds root@PUBLIC_IP
   ```
3. Confirm the warning: the target disk will be wiped during the installation.
4. After reboot the node comes up as a single-node k3s cluster with Traefik, journald limits, and the weekly `crictl rmi --prune` timer.

## C) Rebuilding/updating the VDS with local builds

Run rebuilds locally and push the result to the server over SSH; the server only activates the already built generation:
```bash
sudo nixos-rebuild switch --flake .#vds --target-host root@PUBLIC_IP --build-host localhost
```
This keeps upgrades reproducible and avoids compiling on the low-resource VDS.

## D) Validating Traefik + Let’s Encrypt

1. Point the `DOMAIN` A record to `PUBLIC_IP` and wait for DNS propagation.
2. Deploy any minimal HTTP service (e.g. `whoami`) plus an Ingress or IngressRoute for `DOMAIN` inside the cluster.
3. Verify HTTP/HTTPS:
   ```bash
   curl -I http://DOMAIN
   curl -I https://DOMAIN
   ```
   The HTTPS response must present a valid Let’s Encrypt certificate.
4. Ensure persistence works:
   ```bash
   kubectl -n kube-system get pvc
   kubectl -n kube-system get helmchartconfigs.helm.cattle.io traefik -o yaml
   kubectl -n kube-system logs deploy/traefik --tail=200
   ```
   Restart the Traefik pod (`kubectl -n kube-system rollout restart deploy/traefik`) and confirm that TLS remains valid afterwards (the ACME data is stored in the persistent `acme.json`).

## E) Diagnostics and housekeeping

- Inspect Traefik logs: `kubectl -n kube-system logs deploy/traefik --tail=200`.
- Check the persistence volume: `kubectl -n kube-system get pvc` (the Traefik PVC must be `Bound`).
- ACME state health: restart Traefik and make sure HTTPS keeps working (no rate-limit spikes thanks to persisted `/data/acme.json`).
- Journald usage: `journalctl --disk-usage` should stay below the configured 250 MiB caps.
- Weekly container GC: `systemctl list-timers | grep crictl-prune` to see the timer, and `sudo systemctl start crictl-prune.service` to trigger pruning manually when disk space runs low.

## Acceptance checklist

- `nix flake check` succeeds locally.
- The VM boots, `systemctl status k3s` is green, and `kubectl get pods -A` shows a running Traefik pod.
- After installing onto the VDS, `kubectl get nodes` reports a single Ready node and the Traefik HelmChartConfig manifest exists.
- Traefik provisions Let’s Encrypt certificates once DNS points to the node, and certificates survive pod restarts because of the persistent `/data/acme.json` volume.
- Journald is capped and the weekly `crictl-prune` timer exists and runs successfully.
