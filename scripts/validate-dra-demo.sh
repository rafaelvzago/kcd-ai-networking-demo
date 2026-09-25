#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo
namespace=dra-demo

for pod in dra-consumer-a dra-consumer-b; do
  kubectl --context "$context" wait --namespace "$namespace" --for=condition=Ready "pod/$pod" --timeout=180s
  kubectl --context "$context" logs --namespace "$namespace" "pod/$pod" | grep -Eq 'GPU_DEVICE_[0-9]+=.?gpu-[0-9]+'
done
kubectl --context "$context" get resourceslice -o yaml | grep -q 'driver: gpu.example.com'
kubectl --context "$context" get resourceclaim -n "$namespace" -o yaml | grep -q 'allocation:'
printf '%s\n' 'DRA validado: ResourceSlice, alocação do claim e GPU mock no Pod.'
