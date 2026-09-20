#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo

# Remove workloads das versões anteriores da demo; o namespace é exclusivo dela.
kubectl --context "$context" -n dra-demo delete pod \
  dra-consumer dranet-consumer-a dranet-consumer-b --ignore-not-found

kubectl --context "$context" apply --server-side --filename k8s/dra/workload-combined.yaml
