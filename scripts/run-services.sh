#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ "$(id -un)" != subboost ]; then
  printf '%s\n' 'Run the launcher as subboost, not root.' >&2
  exit 1
fi
state_dir=/opt/subboost-data/ssh
/usr/sbin/sshd -t -f "$state_dir/sshd_config"
/usr/sbin/sshd -D -e -f "$state_dir/sshd_config" &
sshd_pid=$!
started=no
cleanup() {
  if [ "$started" = yes ] && [ -f /opt/subboost-data/enabled ]; then
    python3 /opt/subboost-tools/subboost stop || true
  fi
  kill "$sshd_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM
sleep 1
if ! kill -0 "$sshd_pid" 2>/dev/null; then
  wait "$sshd_pid"
  exit 1
fi
started=yes
printf '%s\n' 'Debian SSH is listening on port 8023. Check this fingerprint on your computer:'
ssh-keygen -lf "$state_dir/host_ed25519.pub"
printf '%s\n' 'Keep this phone terminal open. Ctrl+C stops the enabled services.'
if [ -f /opt/subboost-data/enabled ]; then
  python3 /opt/subboost-tools/subboost start || printf '%s\n' 'App startup failed; SSH remains available for diagnosis.'
fi
wait "$sshd_pid"
