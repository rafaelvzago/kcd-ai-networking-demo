#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
gateway=http://fast-inference-gateway-istio.ai-networking-demo.svc.cluster.local/v1/chat/completions

response=$(kubectl --context "$context" --namespace "$namespace" exec deployment/fast-client -- curl -sS -i -w '\nTTFT: %{time_starttransfer}s\n' -X POST "$gateway" -H 'Content-Type: application/json' --data '{"model":"fast","messages":[{"role":"user","content":"show routing"}]}')
printf '%s\n' "$response"
printf '%s\n' "$response" | grep -qi '^x-inference-pod:'
printf '%s\n' "$response" | grep -q '"usage"'
printf '%s\n' "$response" | grep -q '^TTFT: '
