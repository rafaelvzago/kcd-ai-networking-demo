#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo

bash ./scripts/create-dranet-dummy.sh

kubectl --context "$context" apply --server-side \
  --filename https://raw.githubusercontent.com/kubernetes-sigs/dranet/refs/heads/main/install.yaml
kubectl --context "$context" --namespace kube-system patch daemonset/dranet \
  --type merge \
  --patch '{"spec":{"template":{"spec":{"affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"node-role.kubernetes.io/control-plane","operator":"DoesNotExist"},{"key":"node-role.kubernetes.io/master","operator":"DoesNotExist"}]}]}}}}}}}'
kubectl --context "$context" rollout status --namespace kube-system \
  daemonset/dranet --timeout=180s
kubectl --context "$context" apply --server-side \
  --filename k8s/dra/network-driver.yaml
