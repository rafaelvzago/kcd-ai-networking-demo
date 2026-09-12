#!/usr/bin/env bash
set -euo pipefail

cluster=kcd-ai-networking-demo
image=mock-llm-server:dev

if ! kind get clusters | grep -qx "$cluster"; then
  kind create cluster --name "$cluster"
fi

docker build --tag "$image" .
kind load docker-image --name "$cluster" "$image"
context="kind-$cluster"
kubectl --context "$context" apply --filename k8s/mock-llm.yaml
kubectl --context "$context" rollout status --namespace ai-networking-demo deployment/backend-1
kubectl --context "$context" rollout status --namespace ai-networking-demo deployment/backend-2
kubectl --context "$context" rollout status --namespace ai-networking-demo deployment/backend-3
