#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
chart=oci://ghcr.io/llm-d/charts/llm-d-router-gateway

kubectl --context "$context" apply --filename k8s/mock-llm.yaml
for deployment in backend-1 backend-2 backend-3; do
  kubectl --context "$context" --namespace "$namespace" rollout status "deployment/$deployment"
done

helm upgrade --install demo-fast-router "$chart" --kube-context "$context" \
  --namespace "$namespace" --version v0.9.0 --values k8s/inference/router-fast-values.yaml
helm upgrade --install demo-quality-router "$chart" --kube-context "$context" \
  --namespace "$namespace" --version v0.9.0 --values k8s/inference/router-quality-values.yaml
for deployment in demo-fast-router-epp demo-quality-router-epp; do
  kubectl --context "$context" --namespace "$namespace" rollout status "deployment/$deployment"
done

kubectl --context "$context" apply --filename k8s/inference/model-routing.yaml
