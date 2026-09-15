#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
gateway=http://fast-inference-gateway-istio.ai-networking-demo.svc.cluster.local/v1/chat/completions

request() {
  kubectl --context "$context" --namespace "$namespace" exec deployment/fast-client -- \
    curl -sS -i -X POST "$gateway" -H 'Content-Type: application/json' -H "X-Demo-Pool: $1" \
    -d "{\"model\":\"$1\",\"messages\":[{\"role\":\"user\",\"content\":\"model route check\"}]}"
}

fast=$(request fast)
quality=$(request quality)

printf '%s\n' "$fast" | grep -qi '^x-inference-pod: fast-simulator-'
printf '%s\n' "$quality" | grep -qi '^x-inference-pod: quality-simulator-'
printf '%s\n' 'fast -> fast-simulator'
printf '%s\n' 'quality -> quality-simulator'
