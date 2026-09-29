#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'Run this bootstrap inside the Debian root session.' >&2
  exit 1
fi
if [ -e /opt/subboost ] || [ -e /opt/subboost-data ] || [ -e /opt/subboost-tools ]; then
  printf '%s\n' 'Existing installation detected. Stop and review it; bootstrap is for a fresh environment.' >&2
  exit 1
fi
test -s /mnt/subboost-bootstrap/authorized_keys
apt-get update
apt-get install -y --no-install-recommends \
  openssh-server ca-certificates curl git python3 xz-utils nano postgresql-common
# Do not create the distribution's default cluster in a PRoot root session.
if ! grep -q '^create_main_cluster = false$' /etc/postgresql-common/createcluster.conf; then
  printf '\ncreate_main_cluster = false\n' >> /etc/postgresql-common/createcluster.conf
fi
apt-get install -y --no-install-recommends postgresql-17 postgresql-client-17
if ! id subboost >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --password '*' subboost
fi
install -d -m 755 /run/sshd /opt/subboost-tools
install -d -m 700 /opt/subboost-data /opt/subboost-data/ssh
install -m 600 /mnt/subboost-bootstrap/authorized_keys /opt/subboost-data/ssh/authorized_keys
install -m 600 /mnt/subboost-bootstrap/sshd_config /opt/subboost-data/ssh/sshd_config
ssh-keygen -q -t ed25519 -N '' -f /opt/subboost-data/ssh/host_ed25519
for script in subboost install-node.sh build-app.sh install-cloudflared.py; do
  install -m 700 "/mnt/subboost-bootstrap/$script" "/opt/subboost-tools/$script"
done
git clone --depth 1 --branch v2.8.1 https://github.com/SubBoost/subboost.git /opt/subboost
bash /opt/subboost-tools/install-node.sh
chown -R subboost:subboost /opt/subboost /opt/subboost-tools /opt/subboost-data
printf '%s\n' 'Bootstrap finished. Exit to the native terminal, then launch as subboost.'
