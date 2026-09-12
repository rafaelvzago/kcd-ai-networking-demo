#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
gateway=http://llm-d-inference-gateway.ai-networking-demo.svc.cluster.local/v1/chat/completions

request() {
  kubectl --context "$context" --namespace "$namespace" exec deployment/client-app -- \
    curl -sS -i -X POST "$gateway" -H 'Content-Type: application/json' "$@"
}

backend_request() {
  kubectl --context "$context" --namespace "$namespace" exec deployment/client-app -- \
    curl -sS -i -X POST http://backend-1.ai-networking-demo.svc.cluster.local:8080/v1/chat/completions -H 'Content-Type: application/json' "$@"
}

body() {
  printf '%s\n' "$1" | sed '1,/^\r$/d'
}

printf '%s\n' 'checking workloads'
for deployment in backend-1 backend-2 backend-3 external-mock-llm client-app demo-fast-router-epp demo-quality-router-epp; do
  kubectl --context "$context" --namespace "$namespace" rollout status "deployment/$deployment" --timeout=30s >/dev/null
done
kubectl --context "$context" --namespace "$namespace" wait --for=condition=Programmed gateway/llm-d-inference-gateway --timeout=30s >/dev/null

printf '%s\n' 'checking mock cache and gateway load distribution'
prompt="cache-check-$(date +%s%N)"
payload=$(printf '{"model":"demo","messages":[{"role":"user","content":"%s"}]}' "$prompt")
first=$(backend_request --data "$payload")
second=$(backend_request --data "$payload")
printf '%s\n' "$first" | grep -qi '^X-Cache-Status: MISS'
printf '%s\n' "$second" | grep -qi '^X-Cache-Status: HIT'

instances=$(
  for i in $(seq 1 36); do
    response=$(request --data "{\"model\":\"demo\",\"messages\":[{\"role\":\"user\",\"content\":\"load-check-$i-$(date +%s%N)\"}]}")
    body "$response" | grep -o '"instance":"backend-[123]"' || true
  done | sort -u
)
for backend in backend-1 backend-2 backend-3; do
  if ! printf '%s\n' "$instances" | grep -q "\"instance\":\"$backend\""; then
    printf 'gateway distribution: expected all three backends; observed: %s\n' "$instances" >&2
    exit 1
  fi
done

printf '%s\n' 'checking model routing'
fast=$(request --data '{"model":"demo-fast","messages":[{"role":"user","content":"model route check"}]}')
quality=$(request --data '{"model":"demo-quality","messages":[{"role":"user","content":"model route check"}]}')
body "$fast" | grep -Eq '"instance":"backend-[12]"'
body "$quality" | grep -q '"instance":"backend-3"'

printf '%s\n' 'checking egress credential injection and token quota'
# Wait for a new fixed-window quota interval so a prior manual demo cannot affect this test.
sleep "$((60 - 10#$(date +%S)))"
egress_request() {
  kubectl --context "$context" --namespace "$namespace" exec deployment/client-app -- \
    curl -sS -o /dev/null -w '%{http_code}' -X POST "$gateway" -H 'Host: egress.local' \
    -H 'Content-Type: application/json' --data '{"model":"demo","messages":[{"role":"user","content":"one two three four five six seven eight nine"}]}'
}
first_status=$(egress_request)
second_status=$(egress_request)
if test "$first_status" != 200 || test "$second_status" != 429; then
  printf 'egress quota: expected 200 then 429; got %s then %s\n' "$first_status" "$second_status" >&2
  exit 1
fi

printf '%s\n' 'demo validation passed: mock cache, three backends, model routing, egress auth, and quota'
