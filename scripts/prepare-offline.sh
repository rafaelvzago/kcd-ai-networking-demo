#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
cache_dir=.demo-cache
node=${context#kind-}-control-plane
mkdir -p "$cache_dir"
mkdir -p "$cache_dir/images"

curl --fail --location --output "$cache_dir/gateway-api.yaml" https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml
curl --fail --location --output "$cache_dir/gaie.yaml" https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.5.0/manifests.yaml
helm pull base --repo https://blob.istio.io/istio-release/charts --version 1.31.0 --destination "$cache_dir"
helm pull istiod --repo https://blob.istio.io/istio-release/charts --version 1.31.0 --destination "$cache_dir"
helm pull oci://ghcr.io/llm-d/charts/llm-d-router-gateway --version v0.9.0 --destination "$cache_dir"

for image in \
  docker.io/istio/pilot:1.31.0 \
  docker.io/istio/proxyv2:1.31.0 \
  ghcr.io/llm-d/llm-d-inference-sim:v0.9.0 \
  ghcr.io/llm-d/llm-d-router-endpoint-picker:v0.9.0 \
  docker.io/curlimages/curl:8.15.0; do
  docker pull "$image"
  image_archive="$cache_dir/images/${image//\//_}"
  image_archive="${image_archive//:/_}.tar"
  docker save --output "$image_archive" "$image"
  if ! docker exec "$node" ctr --namespace=k8s.io images list -q | grep -Fxq "$image"; then
    kind load docker-image --name kcd-ai-networking-demo "$image"
  fi
done

printf '%s\n' "Cache offline pronto em $cache_dir"
