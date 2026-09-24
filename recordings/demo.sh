#!/usr/bin/env bash
set -euo pipefail

# Only this demo context is used; the current kubectl context is untouched.
k=(kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo)
gateway=http://fast-inference-gateway-istio.ai-networking-demo.svc.cluster.local/v1/chat/completions

section() {
  printf '\n\033[1;36m%s\033[0m\n\n' "$1"
}

highlight_models() {
  python3 -u -c '
import re, sys
pattern = re.compile(r"(?<![\w-])(?:fast|quality)(?:-(?:route|router|simulator)(?:-[a-z0-9]+)*)?(?![\w-])")
for line in sys.stdin:
    sys.stdout.write(pattern.sub(lambda m: "\033[1;31m" + m[0] + "\033[0m", line))
'
}

pause() {
  if [ "${DEMO_RECORD:-0}" = 1 ]; then
    printf '\nEspaço para continuar.\n'
    sleep 1
  else
    read -r -p 'Pressione Enter para continuar. ' </dev/tty
  fi
}

request() {
  local pool=$1 response payload
  payload="{\"model\":\"$pool\",\"messages\":[{\"role\":\"user\",\"content\":\"Ola KCD Brasil!\"}]}"
  printf '\n$ kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo \\\n'
  printf '  exec deployment/fast-client -- \\\n'
  printf '  curl -sS -i --max-time 15 \\\n'
  printf '    %s \\\n' "'$gateway'" \
    "-H 'Content-Type: application/json'" \
    "-H 'X-Demo-Pool: $pool'" \
    "-d '$payload'"
  printf '%s\n' "    -w '\nTTFT: %{time_starttransfer}s\n'"
  pause
  response=$("${k[@]}" exec deployment/fast-client -- curl -sS -i --max-time 15 \
    -w '\nTTFT: %{time_starttransfer}s\n' "$gateway" \
    -H 'Content-Type: application/json' -H "X-Demo-Pool: $pool" \
    -d "$payload")
  section "Resposta do pool $pool | JSON formatado para leitura"
  printf '%s\n' "$response" | tr -d '\r' | awk '/^HTTP\// || /^x-inference-pod:/ || /^TTFT:/' | highlight_models
  if [ "$pool" = invalid ]; then
    printf '%s\n' "$response" | grep -q '^HTTP/1.1 404'
    if printf '%s\n' "$response" | grep -qi '^x-inference-pod:'; then return 1; fi
  else
    printf '%s\n' "$response" | grep -q '^HTTP/1.1 200'
    printf '%s\n' "$response" | grep -qi "^x-inference-pod: $pool-simulator-"
    printf '%s\n' "$response" | python3 -c '
import json, sys
body = next(line for line in sys.stdin if line.startswith("{"))
data = json.loads(body)
print(json.dumps(data, ensure_ascii=False, indent=2))
' | highlight_models
  fi
  printf '\n'
}

section '1. O caminho de uma chamada'
printf '%s\n' \
  'Cliente: POST /v1/chat/completions' \
  '                |' \
  '                v' \
  '         Istio Gateway' \
  '                |' \
  '       HTTPRoute: X-Demo-Pool' \
  '                |' \
  '     +----------+-----------+' \
  '     |          |           |' \
  '   fast      quality     inválido' \
  '     |          |           |' \
  '     v          v           v' \
  'InferencePool InferencePool  404' \
  ' fast-router  quality-router' \
  '     |          |' \
  '     v          v' \
  '  3 pods      1 pod' \
  '  100 ms      500 ms' \
  '' 'A chamada passa pelo Istio até chegar a um servidor de inferência.' \
  'A rede e o roteamento são reais. Quem responde é o llm-d-inference-sim,' \
  'um simulador que permite executar a demo sem GPU.' \
  '' 'Usamos o formato de API da OpenAI, mas não chamamos OpenAI nem Claude.' \
  'O simulador devolve o texto enviado e reproduz as latências configuradas.' \
  '' 'Cluster: kind-kcd-ai-networking-demo'
pause

section '2. Os servidores de inferência'
printf '%s\n' \
  'Modelo / header -> HTTPRoute -> InferencePool -> EPP -> pods (label app)' \
  'fast -> fast-route -> fast-router -> fast-router-epp -> fast-simulator (3 pods)' \
  'quality -> quality-route -> quality-router -> quality-router-epp -> quality-simulator (1 pod)' \
  '' 'Gateway compartilhado: fast-inference-gateway (Istio).' '' | highlight_models
printf '%s\n' 'O pool fast tem três réplicas; o quality tem uma.' \
  'Cada InferencePool agrupa os pods que podem atender aquele modelo.' \
  '' 'O header X-Demo-Pool escolhe o pool. Dentro dele, o roteador escolhe o pod.' \
  'Vamos conferir quais servidores estão disponíveis.'
pause
printf "$ kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get pods -l 'app in (fast-simulator,quality-simulator)' -o yaml | python3 recordings/demo-yaml.py\n\n"
"${k[@]}" get pods -l 'app in (fast-simulator,quality-simulator)' -o yaml | python3 recordings/demo-yaml.py | highlight_models
pause

section '2. InferencePools'
printf '$ kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get inferencepools -o yaml | python3 recordings/demo-yaml.py\n\n'
"${k[@]}" get inferencepools -o yaml | python3 recordings/demo-yaml.py | highlight_models
pause

section '2. HTTPRoutes'
printf '$ kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get httproutes -o yaml | python3 recordings/demo-yaml.py\n\n'
"${k[@]}" get httproutes -o yaml | python3 recordings/demo-yaml.py | highlight_models
pause

section '3. Uma chamada ao modelo rápido'
printf '%s\n' \
  '[Cliente] -- X-Demo-Pool: fast --> [Istio / HTTPRoute]' \
  '                                          |' \
  '                                          v' \
  '                             [InferencePool fast-router]' \
  '                                          | escolhe 1 dos 3 pods' \
  '                                          v' \
  '                               [fast-simulator: 100 ms]' ''
printf '%s\n' 'Com X-Demo-Pool: fast, a chamada vai para o pool rápido.' \
  'O header x-inference-pod revela qual réplica respondeu.' \
  '' 'Configuramos 100 ms até o primeiro token no simulador.' \
  'O curl mede o tempo até o primeiro byte, usado aqui como aproximação do TTFT.' \
  'Esse tempo também inclui a passagem pela rede e pelo gateway.'
pause
request fast
pause

section '4. Distribuição entre as réplicas'
printf '%s\n' 'Chamadas sequenciais podem chegar sempre ao mesmo pod.' \
  'Vamos enviar 12 chamadas concorrentes, com textos distintos, e contar' \
  'quantas respostas vieram de cada réplica.' \
  '' 'A distribuição não precisa ser uniforme. A contagem mostra o que aconteceu' \
  'nesta execução, sem presumir uma ordem fixa entre os pods.'
pause
burst='
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    curl -sS -i --max-time 15 \
      http://fast-inference-gateway-istio.ai-networking-demo.svc.cluster.local/v1/chat/completions \
      -H "Content-Type: application/json" -H "X-Demo-Pool: fast" \
      -d "{\"model\":\"fast\",\"messages\":[{\"role\":\"user\",\"content\":\"Pedido $i\"}]}" \
      | grep -i "^x-inference-pod:" &
  done
  wait
'
section '4. As 12 chamadas concorrentes'
printf '$ kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo \\\n'
printf "  exec deployment/fast-client -- sh -c '%s'\n" "$burst"
pause
pods=$("${k[@]}" exec deployment/fast-client -- sh -c "$burst" | tr -d '\r' | awk '{print $2}')
test "$(printf '%s\n' "$pods" | grep -c '^fast-simulator-')" -eq 12
test "$(printf '%s\n' "$pods" | sort -u | wc -l)" -gt 1
printf 'Chamadas por pod (distribuicao observada):\n'
printf '%s\n' "$pods" | sort | uniq -c | highlight_models
pause

section '5. Uma chamada ao modelo de qualidade'
printf '%s\n' \
  '[Cliente] -- X-Demo-Pool: quality --> [Istio / HTTPRoute]' \
  '                                             |' \
  '                                             v' \
  '                               [InferencePool quality-router]' \
  '                                             | 1 pod disponível' \
  '                                             v' \
  '                                 [quality-simulator: 500 ms]' ''
printf '%s\n' 'Ao enviar X-Demo-Pool: quality, escolhemos outro pool.' \
  'Ele tem uma réplica e 500 ms configurados até o primeiro token.' \
  '' 'Compare o pod e a latência com as respostas de fast.' \
  'O nome quality ilustra outro perfil de modelo. Como a resposta é simulada,' \
  'esta demo não mede a qualidade de um modelo real.'
pause
request quality
pause

section '6. Um pool que não existe'
printf '%s\n' 'As rotas aceitam fast ou quality no header X-Demo-Pool.' \
  'O valor invalid não corresponde a nenhuma delas, então o gateway retorna 404.' \
  '' 'A chamada não chega aos simuladores. Na resposta, esperamos ver o erro' \
  'sem o header x-inference-pod.'
pause
request invalid
pause

section '7. Conferindo o resultado'
printf '%s\n' 'O script de validação faz uma chamada para cada pool.' \
  'Ele confere se os pods pertencem aos pools esperados e se fast respondeu' \
  'com latência menor que quality.' \
  '' 'Essas verificações confirmam o roteamento e a diferença de latência' \
  'que acabamos de observar.'
pause
printf '$ bash scripts/validate-model-routing.sh\n\n'
bash scripts/validate-model-routing.sh
printf '\nValidado: pods dos pools corretos e TTFT de fast menor que quality.\n'
printf '\nClusters preservados. Nenhuma instalacao durante a gravacao.\n'
pause
