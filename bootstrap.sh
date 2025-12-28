#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--ssh-user USER] PUBLIC_IP

Runs a small interactive wizard that:
  * ensures an ed25519 SSH keypair exists locally (and copies it to the server),
  * optionally asks for hostname/domain/ACME email overrides,
  * runs nixos-anywhere with the provided server IP.
EOF
}

SSH_USER="root"
PUBLIC_IP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-user)
      [[ $# -ge 2 ]] || { echo "Missing value for --ssh-user" >&2; exit 1; }
      SSH_USER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$PUBLIC_IP" ]]; then
        PUBLIC_IP="$1"
        shift
      else
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$PUBLIC_IP" ]]; then
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== nix-k3s bootstrap helper ==="
printf 'Target: %s@%s\n\n' "$SSH_USER" "$PUBLIC_IP"

read -rp "Hostname for the VDS (blank = keep flake default): " INPUT_HOSTNAME || true
read -rp "Domain for the built-in status check (blank = skip): " INPUT_DOMAIN || true
read -rp "Let's Encrypt email (blank = keep flake default): " INPUT_EMAIL || true

KEY_PATH="${HOME}/.ssh/id_ed25519"
PUB_PATH="${KEY_PATH}.pub"
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Generating a new SSH keypair at ${KEY_PATH} ..."
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "nix-k3s"
fi
if [[ ! -f "$PUB_PATH" ]]; then
  echo "Cannot find public key at ${PUB_PATH}" >&2
  exit 1
fi
SSH_PUB="$(tr -d '\n' < "$PUB_PATH")"

if command -v ssh-copy-id >/dev/null 2>&1; then
  echo "Installing the public key on ${SSH_USER}@${PUBLIC_IP} (password may be requested once)..."
  ssh-copy-id -i "$PUB_PATH" "${SSH_USER}@${PUBLIC_IP}"
else
  cat <<EOF
WARNING: ssh-copy-id not found. Please add ${PUB_PATH} to ${SSH_USER}@${PUBLIC_IP}:~/.ssh/authorized_keys manually
before rerunning this script if you want passwordless access.
EOF
fi

set_env_var() {
  local name="$1"
  local value="$2"
  printf -v "$name" '%s' "$value"
  export "$name"
}

set_env_var "NIX_K3S_PUBLIC_IP" "$PUBLIC_IP"
set_env_var "NIX_K3S_SSH_KEY" "$SSH_PUB"
[[ -n "${INPUT_HOSTNAME:-}" ]] && set_env_var "NIX_K3S_HOSTNAME" "$INPUT_HOSTNAME"
[[ -n "${INPUT_DOMAIN:-}" ]] && set_env_var "NIX_K3S_DOMAIN" "$INPUT_DOMAIN"
[[ -n "${INPUT_EMAIL:-}" ]] && set_env_var "NIX_K3S_LE_EMAIL" "$INPUT_EMAIL"

echo
echo "Starting nixos-anywhere (this will take a while and will reboot the server)..."
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- --flake .#vds "${SSH_USER}@${PUBLIC_IP}"
