#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
istio_version=1.31.0

if [ "$(sysctl -n fs.inotify.max_user_instances)" -lt 512 ]; then
  echo "Kind precisa de fs.inotify.max_user_instances >= 512. Rode:"
  echo "  sudo sysctl -w fs.inotify.max_user_instances=512"
  exit 1
fi

kubectl --context "$context" apply --server-side --filename https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
kubectl --context "$context" apply --server-side --filename https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml
helm upgrade --install istio-base base --repo https://blob.istio.io/istio-release/charts --kube-context "$context" --namespace istio-system --create-namespace --version "$istio_version"
helm upgrade --install istiod istiod --repo https://blob.istio.io/istio-release/charts --kube-context "$context" --namespace istio-system --version "$istio_version" --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true
kubectl --context "$context" rollout status --namespace istio-system deployment/istiod --timeout=180s
kubectl --context "$context" get gatewayclass istio >/dev/null
kubectl --context "$context" apply --filename k8s/fast-inference.yaml --filename k8s/fast-inference-gateway.yaml
kubectl --context "$context" rollout status --namespace "$namespace" deployment/fast-simulator
kubectl --context "$context" rollout status --namespace "$namespace" deployment/fast-client
helm upgrade --install fast-router oci://ghcr.io/llm-d/charts/llm-d-router-gateway --kube-context "$context" --namespace "$namespace" --version v0.9.0 --values k8s/fast-router-values.yaml
kubectl --context "$context" wait --namespace "$namespace" --for=condition=Programmed gateway/fast-inference-gateway --timeout=180s
