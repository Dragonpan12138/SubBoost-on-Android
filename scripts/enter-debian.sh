#!/usr/bin/env bash
set -euo pipefail

phone_prefix=${PREFIX:?Run this in the native DroidDesk terminal, not inside Debian.}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export HOME="$(dirname "$phone_prefix")/home"
export TERMUX__PREFIX="$phone_prefix"
export TERMUX_APP__PACKAGE_NAME=com.orailnoor.droiddesk
export TERMUX_APP_PACKAGE_MANAGER=apt
export PROOT_LOADER="$phone_prefix/libexec/proot/loader"
export PROOT_LOADER_32="$phone_prefix/libexec/proot/loader32"
export PROOT_TMP_DIR="$phone_prefix/tmp/subboost-proot"
export PROOT_NO_SECCOMP=1
export PATH="$phone_prefix/bin:/system/bin"
export LD_LIBRARY_PATH="$phone_prefix/lib"
mkdir -p "$PROOT_TMP_DIR"
unset LD_PRELOAD

user=subboost
case "${1:-}" in
  --root) user=root; shift ;;
esac
if [ "$#" -eq 0 ]; then
  set -- /bin/bash /mnt/subboost-bootstrap/run-services.sh
fi

exec "$phone_prefix/bin/proot-distro" login debian \
  --user "$user" \
  --bind "$script_dir:/mnt/subboost-bootstrap" \
  --env "PROOT_TMP_DIR=$PROOT_TMP_DIR" \
  --env "PROOT_LOADER=$PROOT_LOADER" \
  --env "PROOT_LOADER_32=$PROOT_LOADER_32" \
  --env "PROOT_DONT_SHARE_LIBANDROID_SHMEM=1" \
  -- "$@"
