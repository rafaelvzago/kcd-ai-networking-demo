#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo
namespace=dra-demo

for pod in dra-consumer-a dra-consumer-b; do
  kubectl --context "$context" wait --namespace "$namespace" \
    --for=condition=Ready "pod/$pod" --timeout=180s
  kubectl --context "$context" logs --namespace "$namespace" "pod/$pod" \
    | grep -q 'dranet0'
  kubectl --context "$context" logs --namespace "$namespace" "pod/$pod" \
    | grep -Eq '169\.254\.10\.[12]/30'
done
kubectl --context "$context" get resourceslice -o yaml \
  | grep -q 'driver: dra.net'
kubectl --context "$context" get resourceclaim --namespace "$namespace" -o yaml \
  | grep -q 'allocation:'
printf '%s\n' \
  'DRANET validado: claims alocados e dranet0 visível nos dois Pods.' \
  'Endereços 169.254.10.1/30 e 169.254.10.2/30 visíveis; não há conectividade entre os dummies.' \
  'Limite: isso não representa RDMA, desempenho ou hardware de rede real.'
