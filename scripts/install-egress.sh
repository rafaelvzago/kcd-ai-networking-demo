#!/usr/bin/env bash
set -euo pipefail

context=kind-kcd-ai-networking-demo
kubectl --context "$context" apply --filename k8s/egress/egress.yaml
kubectl --context "$context" rollout status --namespace ai-networking-demo deployment/external-mock-llm
kubectl --context "$context" rollout status --namespace ai-networking-demo deployment/client-app
