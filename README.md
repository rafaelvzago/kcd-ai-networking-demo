# KCD Brasil 2026: demonstração de networking para IA

Este repositório reúne a demo da palestra "A Evolução do Kubernetes Networking na Era da IA", apresentada no KCD Brasil 2026.

## Documentação

- [ADR-001](docs/adr/0001-mock-model-server-adr.md): decisão de arquitetura da demonstração prática.
- [PRD-001](docs/prd/0001-mock-model-server-prd.md): requisitos e casos de teste.

## Pré-requisitos

- Go 1.27+
- Docker
- Kind
- `kubectl`
- Helm

Comece com:

```bash
make help
make test
```

## Validar o mock em Go

Em um terminal:

```bash
make run
```

Em outro terminal, envie a primeira chamada:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"demo","messages":[{"role":"user","content":"cache me"}]}'
```

Espere `200`, `X-Cache-Status: MISS` e `X-Instance-Name: mock-llm-server`. Repita o comando. A segunda resposta deve ter `X-Cache-Status: HIT`.

O JSON tem precedência sobre o header de delay:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'X-Simulate-Delay-MS: nope' \
  -d '{"model":"demo","messages":[{"role":"user","content":"delay override"}],"simulate_delay_ms":0}'
```

Essa chamada deve retornar `200`.

Valide a entrada inválida:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"","messages":[]}'
```

O resultado esperado é `400 Bad Request`. Pare o processo com `Ctrl-C` antes da próxima etapa.

## Validar o container

```bash
make image
docker run --rm -p 8080:8080 \
  -e INSTANCE_NAME=local-container \
  -e REQUIRED_API_KEY=demo \
  mock-llm-server:dev
```

Em outro terminal, esta chamada deve retornar `401`:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"demo","messages":[{"role":"user","content":"secure request"}]}'
```

Com a chave, deve retornar `200`:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer demo' \
  -d '{"model":"demo","messages":[{"role":"user","content":"secure request"}]}'
```

Pare o container com `Ctrl-C`.

## Validar no Kind

```bash
make bootstrap
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get deployments,pods,service
```

Os três pods, `backend-1`, `backend-2` e `backend-3`, devem estar `Running`. Em um terminal:

```bash
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo port-forward service/mock-llm 8080:8080
```

Repita o teste de cache. O primeiro prompt novo deve ser `MISS`; a repetição deve ser `HIT`. O `port-forward` fixa a sessão em uma réplica, o que é esperado.

## InferencePool

O script usa Gateway API `v1.6.0`, GAIE `v1.5.0`, Agentgateway `v1.4.1` e llm-d Router `v0.9.0`.

```bash
make inference
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get gateway,httproute,inferencepool
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo port-forward service/llm-d-inference-gateway 8080:80
```

Em outro terminal:

```bash
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"demo","messages":[{"role":"user","content":"through inference pool"}]}'
```

Espere `200`, `X-Instance-Name: backend-<n>` e `x-went-into-resp-headers: true`. A chamada passou pelo Gateway e pelo `InferencePool`.

Envie prompts distintos para observar a distribuição entre os três backends:

```bash
for i in $(seq 1 10); do
  curl -s -X POST http://localhost:8080/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"demo\",\"messages\":[{\"role\":\"user\",\"content\":\"backend check $i\"}]}" \
    | grep -o '"instance":"backend-[0-9]"'
done
```

Os resultados devem incluir `backend-1`, `backend-2` e `backend-3`. Repetir um prompt já enviado demonstra a afinidade de cache.

## Roteamento por modelo

O cenário adicional usa dois pools. `demo-fast` vai para `backend-1` ou `backend-2`; `demo-quality` vai para `backend-3`.

```bash
make model-routing
make validate-model-routing
```

O segundo comando envia as duas requisições pelo Gateway e falha se `demo-fast` não chegar a `backend-1` ou `backend-2`, ou se `demo-quality` não chegar a `backend-3`.

## Egress e quota

O cenário de Egress tem um cliente sem chave, um upstream protegido por `Secret` e uma quota local de 20 tokens por minuto.

```bash
make egress
```

Faça duas chamadas consecutivas para não cruzar a virada do minuto:

```bash
for i in 1 2; do
  kubectl --context kind-kcd-ai-networking-demo \
    -n ai-networking-demo exec deployment/client-app -- \
    curl -s -o /dev/null -w "chamada $i: HTTP %{http_code}\n" \
    http://llm-d-inference-gateway.ai-networking-demo.svc.cluster.local/v1/chat/completions \
    -H 'Host: egress.local' \
    -H 'Content-Type: application/json' \
    -d '{"model":"demo","messages":[{"role":"user","content":"token budget test"}]}'
done
```

Espere `chamada 1: HTTP 200` e `chamada 2: HTTP 429`. O cliente não envia `Authorization`; o Agentgateway lê `upstream-api-key` e injeta o token Bearer no upstream.
