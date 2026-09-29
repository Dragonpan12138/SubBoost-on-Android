#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
tools_dir=/opt/subboost-tools
install -d "$tools_dir/cache" "$tools_dir/node"
cd "$tools_dir/cache"
curl --fail --location --retry 3 --connect-timeout 20 --max-time 120 \
  https://nodejs.org/dist/v22.23.3/SHASUMS256.txt -o node-shasums.txt
node_archive=$(awk '$2 ~ /^node-v22\.[0-9]+\.[0-9]+-linux-arm64\.tar\.xz$/ {print $2}' node-shasums.txt)
if [[ ! "$node_archive" =~ ^node-v22\.[0-9]+\.[0-9]+-linux-arm64\.tar\.xz$ ]]; then
  printf '%s\n' 'Could not identify the official ARM64 Node.js archive.' >&2
  exit 1
fi
curl --fail --location --retry 3 --connect-timeout 20 --max-time 600 \
  "https://nodejs.org/dist/v22.23.3/$node_archive" -o "$node_archive"
awk -v archive="$node_archive" '$2 == archive' node-shasums.txt | sha256sum --check --strict
tar -xJf "$node_archive" --strip-components=1 -C "$tools_dir/node"
"$tools_dir/node/bin/node" --version
