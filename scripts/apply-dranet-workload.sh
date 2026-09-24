#!/usr/bin/env bash
set -euo pipefail

kubectl --context kind-dra-demo apply --server-side \
  --filename k8s/dra/workload-combined.yaml
