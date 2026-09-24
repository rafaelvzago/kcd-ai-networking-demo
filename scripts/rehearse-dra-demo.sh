#!/usr/bin/env bash
set -euo pipefail

context=kind-dra-demo
namespace=dra-demo

command -v yq >/dev/null 2>&1 || {
  printf '%s\n' 'Pré-requisito ausente: instale yq para compactar os YAMLs da gravação.' >&2
  exit 1
}

title() {
  printf '\n\n=== %s ===\n' "$1"
  sleep 0.6
}

say() {
  printf '\n%s\n' "$1"
  sleep 0.6
}

colorize() {
  local red reset
  printf -v red '\033[1;31m'
  printf -v reset '\033[0m'

  if [[ -z ${DRA_COLOR:-} && ( -n ${NO_COLOR:-} || ${TERM:-} == dumb || ( ! -t 1 && -z ${ASCIINEMA_SESSION:-} ) ) ]]; then
    sed -n p
    return
  fi

  sed \
    -e "s/\<\(driver\|deviceClassName\|status\|allocation\|networkData\|interfaceName\|dranet0\|allocated\)\>/${red}&${reset}/g" \
    -e "s/GPU_DEVICE_[[:alnum:]_]*/${red}&${reset}/g" \
    -e "s/\<gpu\.example\.com\|dra\.net\>/${red}&${reset}/g" \
    -e "s#[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}\(/[0-9]\{1,2\}\)\?#${red}&${reset}#g"
}

run() {
  printf '\n$ %s\n' "$*"
  "$@" | colorize
  sleep 0.6
}

run_yaml() {
  local filter=$1
  shift
  printf '\n$ %s -o yaml | yq\n' "$*"
  "$@" | yq -P "$filter" | colorize
  sleep 0.6
}

title '1. Visão geral do cluster'
say 'Começamos pelos nós para confirmar onde os drivers e os Pods podem ser executados.'
run kubectl --context "$context" get nodes -o wide

title '2. Drivers DRA em execução'
say 'Os DaemonSets publicam a GPU mock e os devices de rede; ambos são somente consultados aqui.'
run kubectl --context "$context" --namespace "$namespace" get daemonset,pods
run kubectl --context "$context" --namespace kube-system get daemonset,pods -l app=dranet

title '3. DeviceClass: quais devices podem ser selecionados'
say 'Estas classes ligam os claims aos drivers gpu.example.com e dra.net.'
run_yaml '{"apiVersion": .apiVersion, "kind": .kind, "items": [.items[] | {"apiVersion": .apiVersion, "kind": .kind, "metadata": {"name": .metadata.name}, "spec": {"selectors": .spec.selectors}}]}' kubectl --context "$context" get deviceclass gpu.example.com dranet.net

title '4. ResourceSlices: inventário publicado pelos nós'
say 'Cada slice mostra os devices disponíveis e em qual nó o scheduler pode encontrá-los.'
run_yaml '{"apiVersion": .apiVersion, "kind": .kind, "items": [.items[] | {"apiVersion": .apiVersion, "kind": .kind, "spec": {"nodeName": .spec.nodeName, "driver": .spec.driver, "devices": [.spec.devices[] | {"name": .name, "capacity": .capacity} | with_entries(select(.value != null))]}}]}' kubectl --context "$context" get resourceslices

title '5. ResourceClaimTemplates: o pedido declarado pelo workload'
say 'Os templates pedem uma GPU e uma interface específica, incluindo nome e endereço da interface.'
run_yaml '{
  "apiVersion": .apiVersion,
  "kind": .kind,
  "items": [.items[] | {
    "apiVersion": .apiVersion,
    "kind": .kind,
    "spec": {
      "spec": {
        "devices": ({
          "config": (.spec.spec.devices.config // [] | map({"opaque": {"driver": .opaque.driver, "parameters": {"interface": .opaque.parameters.interface}}})),
          "requests": (.spec.spec.devices.requests | map({"exactly": {"deviceClassName": .exactly.deviceClassName, "selectors": .exactly.selectors}, "name": .name}))
        } | with_entries(select(.value != null and ((.value | type) != "!!seq" or (.value | length) > 0))))
      }
    }
  }]
}' kubectl --context "$context" --namespace "$namespace" get resourceclaimtemplates

title '6. ResourceClaims: resultado da alocação'
say 'Procure status.allocation, que registra o device escolhido, e status.networkData, com a configuração entregue pelo driver.'
run_yaml '{"apiVersion": .apiVersion, "kind": .kind, "items": [.items[] | {"apiVersion": .apiVersion, "kind": .kind, "status": ({"allocation": {"devices": (.status.allocation.devices.results // [] | map({"device": .device, "driver": .driver, "pool": .pool, "request": .request}))}, "devices": (.status.devices // [] | map({"device": .device, "driver": .driver, "networkData": {"interfaceName": .networkData.interfaceName, "ips": .networkData.ips}}))} | with_entries(select(.value != null and ((.value | type) != "!!seq" or (.value | length) > 0))))}]}' kubectl --context "$context" --namespace "$namespace" get resourceclaims

title '7. Pods consumidores'
say 'Agora conferimos os dois Pods, seus nós e o vínculo com os ResourceClaims.'
run kubectl --context "$context" --namespace "$namespace" get pods -o wide

for pod in dra-consumer-a dra-consumer-b; do
  title "8. Dentro de $pod: GPU mock e rede"
  say 'A variável GPU_DEVICE_* confirma a alocação da GPU; ip addr confirma a interface dranet0 e seu endereço.'
  run kubectl --context "$context" --namespace "$namespace" exec "$pod" -- sh -c 'env | grep "^GPU_DEVICE_" || true; ip addr'
done
