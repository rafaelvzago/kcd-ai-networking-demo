#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
namespace=ai-networking-demo
istio_version=1.31.0
cache_dir=.demo-cache

if [ "${OFFLINE:-}" = 1 ]; then
  for artifact in gateway-api.yaml gaie.yaml base-1.31.0.tgz istiod-1.31.0.tgz llm-d-router-gateway-v0.9.0.tgz; do
    test -f "$cache_dir/$artifact" || { echo "Artefato offline ausente: $cache_dir/$artifact"; exit 1; }
  done
  gateway_api="$cache_dir/gateway-api.yaml"
  gaie="$cache_dir/gaie.yaml"
  istio_base="$cache_dir/base-1.31.0.tgz"
  istiod="$cache_dir/istiod-1.31.0.tgz"
  router_chart="$cache_dir/llm-d-router-gateway-v0.9.0.tgz"
else
  gateway_api=https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
  gaie=https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml
  istio_base=base
  istiod=istiod
  router_chart=oci://ghcr.io/llm-d/charts/llm-d-router-gateway
fi

if [ "$(sysctl -n fs.inotify.max_user_instances)" -lt 512 ]; then
  echo "Kind precisa de fs.inotify.max_user_instances >= 512. Rode:"
  echo "  sudo sysctl -w fs.inotify.max_user_instances=512"
  exit 1
fi

kubectl --context "$context" apply --server-side --filename "$gateway_api"
kubectl --context "$context" apply --server-side --filename "$gaie"
if [ "${OFFLINE:-}" = 1 ]; then
  helm upgrade --install istio-base "$istio_base" --kube-context "$context" --namespace istio-system --create-namespace
  helm upgrade --install istiod "$istiod" --kube-context "$context" --namespace istio-system --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true
else
  helm upgrade --install istio-base "$istio_base" --repo https://blob.istio.io/istio-release/charts --kube-context "$context" --namespace istio-system --create-namespace --version "$istio_version"
  helm upgrade --install istiod "$istiod" --repo https://blob.istio.io/istio-release/charts --kube-context "$context" --namespace istio-system --version "$istio_version" --set pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true
fi
kubectl --context "$context" rollout status --namespace istio-system deployment/istiod --timeout=180s
kubectl --context "$context" get gatewayclass istio >/dev/null
kubectl --context "$context" create namespace "$namespace" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" apply --filename k8s/fast-inference.yaml --filename k8s/fast-inference-gateway.yaml
kubectl --context "$context" rollout status --namespace "$namespace" deployment/fast-simulator
kubectl --context "$context" rollout status --namespace "$namespace" deployment/fast-client
if [ "${OFFLINE:-}" = 1 ]; then
  helm upgrade --install fast-router "$router_chart" --kube-context "$context" --namespace "$namespace" --values k8s/fast-router-values.yaml
else
  helm upgrade --install fast-router "$router_chart" --kube-context "$context" --namespace "$namespace" --version v0.9.0 --values k8s/fast-router-values.yaml
fi
kubectl --context "$context" wait --namespace "$namespace" --for=condition=Programmed gateway/fast-inference-gateway --timeout=180s
kubectl --context "$context" rollout status --namespace "$namespace" deployment/fast-inference-gateway-istio --timeout=180s
