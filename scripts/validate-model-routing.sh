#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
gateway=http://llm-d-inference-gateway.ai-networking-demo.svc.cluster.local/v1/chat/completions

request() {
  kubectl --context "$context" --namespace "$namespace" exec deployment/client-app -- \
    curl -s -X POST "$gateway" -H 'Content-Type: application/json' \
    -d "{\"model\":\"$1\",\"messages\":[{\"role\":\"user\",\"content\":\"model route check\"}]}"
}

fast=$(request demo-fast)
quality=$(request demo-quality)

printf '%s\n' "$fast" | grep -Eq '"instance":"backend-[12]"'
printf '%s\n' "$quality" | grep -q '"instance":"backend-3"'
printf '%s\n' 'demo-fast -> backend-1 or backend-2'
printf '%s\n' 'demo-quality -> backend-3'
