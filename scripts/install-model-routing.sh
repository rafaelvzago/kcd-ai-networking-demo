#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
chart=oci://ghcr.io/llm-d/charts/llm-d-router-gateway

if [ "${OFFLINE:-}" = 1 ]; then
  chart=.demo-cache/llm-d-router-gateway-v0.9.0.tgz
fi

bash ./scripts/install-fast-inference.sh

if [ "${OFFLINE:-}" = 1 ]; then
  helm upgrade fast-router "$chart" --kube-context "$context" --namespace "$namespace" \
    --values k8s/fast-router-values.yaml --set httpRoute.create=false
  helm upgrade --install quality-router "$chart" --kube-context "$context" --namespace "$namespace" \
    --values k8s/quality-router-values.yaml
else
  helm upgrade fast-router "$chart" --kube-context "$context" --namespace "$namespace" \
    --version v0.9.0 --values k8s/fast-router-values.yaml --set httpRoute.create=false
  helm upgrade --install quality-router "$chart" --kube-context "$context" --namespace "$namespace" \
    --version v0.9.0 --values k8s/quality-router-values.yaml
fi
for deployment in fast-router-epp quality-router-epp; do
  kubectl --context "$context" --namespace "$namespace" set resources "deployment/$deployment" \
    --requests=cpu=100m,memory=128Mi
done
for deployment in fast-router-epp quality-router-epp quality-simulator; do
  kubectl --context "$context" --namespace "$namespace" rollout status "deployment/$deployment"
done

kubectl --context "$context" apply --filename k8s/model-routes.yaml
for route in fast-route quality-route; do
  kubectl --context "$context" --namespace "$namespace" wait \
    --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True "httproute/$route" --timeout=180s
  kubectl --context "$context" --namespace "$namespace" wait \
    --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True "httproute/$route" --timeout=180s
done
