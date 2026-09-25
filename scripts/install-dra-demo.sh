#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo
node_image=${KIND_NODE_IMAGE:-kindest/node:v1.37.0}

kind create cluster --name dra-demo --image "$node_image" --config k8s/dra/kind.yaml
kubectl --context "$context" apply --server-side --filename k8s/dra/driver.yaml
kubectl --context "$context" rollout status --namespace dra-demo daemonset/dra-example-driver --timeout=180s
