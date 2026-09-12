#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo

kubectl --context "$context" apply --server-side --filename \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
kubectl --context "$context" apply --server-side --filename \
  https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml

helm upgrade --install agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --kube-context "$context" --namespace agentgateway-system --create-namespace --version v1.4.1
helm upgrade --install agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --kube-context "$context" --namespace agentgateway-system --version v1.4.1 \
  --set inferenceExtension.enabled=true

kubectl --context "$context" apply --filename k8s/inference/gateway.yaml
kubectl --context "$context" wait --namespace "$namespace" \
  --for=condition=Programmed gateway/llm-d-inference-gateway --timeout=180s

helm upgrade --install mock-llm-router oci://ghcr.io/llm-d/charts/llm-d-router-gateway \
  --kube-context "$context" --namespace "$namespace" --version v0.9.0 \
  --values k8s/inference/router-values.yaml
