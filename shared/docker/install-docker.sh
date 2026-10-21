#!/usr/bin/env bash
# Install Docker Engine with the Compose plugin from Docker's own repository,
# plus jq and curl. Runs on the server with sudo. Used by the self-hosted
# NetBird and Pangolin guides.
#
#   sudo DOCKER_USER=alice ./install-docker.sh
#
# DOCKER_USER, when set, joins the docker group. That group can control the
# Docker daemon, which runs as root, so it is root-equivalent: add only yourself.
# Log out and back in afterwards for the group to apply.
set -euo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

[[ "$(id -u)" -eq 0 ]] || die "Run with sudo."
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] || die "Tested on Debian 13 only."

export DEBIAN_FRONTEND=noninteractive
info "Adding Docker's apt repository for ${VERSION_CODENAME}"
apt-get update -q
apt-get install -y -q ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

info "Installing Docker, the Compose plugin and jq"
apt-get update -q
apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin jq

if [[ -n "${DOCKER_USER:-}" ]]; then
  id "$DOCKER_USER" > /dev/null 2>&1 || die "User $DOCKER_USER does not exist."
  usermod -aG docker "$DOCKER_USER"
  info "$DOCKER_USER joined the docker group (root-equivalent). Log out and back in to use it."
fi

docker --version
docker compose version
jq --version
