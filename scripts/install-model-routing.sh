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
for deployment in fast-router-epp quality-router-epp quality-simulator; do
  kubectl --context "$context" --namespace "$namespace" rollout status "deployment/$deployment"
done

kubectl --context "$context" apply --filename k8s/model-routes.yaml
