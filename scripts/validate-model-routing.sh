#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
gateway=http://fast-inference-gateway-istio.ai-networking-demo.svc.cluster.local/v1/chat/completions

request() {
  local response attempt
  for attempt in {1..10}; do
    response=$(kubectl --context "$context" --namespace "$namespace" exec deployment/fast-client -- \
      curl -sS -i -w '\nTTFT: %{time_starttransfer}\n' -X POST "$gateway" -H 'Content-Type: application/json' -H "X-Demo-Pool: $1" \
      -d "{\"model\":\"$1\",\"messages\":[{\"role\":\"user\",\"content\":\"model route check\"}]}")
    if grep -qi "^x-inference-pod: $1-simulator-" <<<"$response"; then
      printf '%s\n' "$response"
      return
    fi
    sleep 1
  done
  printf 'No route to %s after 10 attempts:\n%s\n' "$1" "$response" >&2
  return 1
}

fast=$(request fast)
quality=$(request quality)
trap 'printf "fast response:\n%s\nquality response:\n%s\n" "$fast" "$quality" >&2' ERR

fast_ttft=$(printf '%s\n' "$fast" | awk '/^TTFT:/{print $2}')
quality_ttft=$(printf '%s\n' "$quality" | awk '/^TTFT:/{print $2}')
awk -v fast="$fast_ttft" -v quality="$quality_ttft" 'BEGIN { exit !(fast < quality) }'
printf '%s\n' 'fast -> fast-simulator'
printf '%s\n' 'quality -> quality-simulator'
printf '%s\n' "TTFT: fast=${fast_ttft}s quality=${quality_ttft}s"
