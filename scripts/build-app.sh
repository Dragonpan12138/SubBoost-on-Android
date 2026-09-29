#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/subboost-tools/node/bin:/usr/local/bin:/usr/bin:/bin
export NEXT_TELEMETRY_DISABLED=1
export NODE_OPTIONS=--max-old-space-size=2048
cd /opt/subboost
npm run build
