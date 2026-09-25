#!/usr/bin/env bash
set -euo pipefail

for pair in 'dra-demo-worker dranet-dummy0' 'dra-demo-worker2 dranet-dummy1'; do
  read -r worker interface <<<"$pair"
  docker exec "$worker" sh -c "
    ip link show '$interface' >/dev/null 2>&1 || ip link add '$interface' type dummy
    ip link set '$interface' up
  "
done
