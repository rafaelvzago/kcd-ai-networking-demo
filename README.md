# KCD Brasil 2026: demonstração de networking para IA

Este repositório reúne a demo da palestra "A Evolução do Kubernetes Networking na Era da IA", apresentada no KCD Brasil 2026.

## Documentação

- [ADR-001](docs/adr/0001-mock-model-server-adr.md): decisão de arquitetura da demonstração prática.
- [PRD-001](docs/prd/0001-mock-model-server-prd.md): requisitos e casos de teste.

## Mock local

```bash
go test ./...
docker build -t mock-llm-server:dev .
./scripts/bootstrap-kind.sh
```

O bootstrap cria o cluster `kcd-ai-networking-demo`, carrega a imagem local e sobe `backend-1`, `backend-2` e `backend-3` no namespace `ai-networking-demo`.

```bash
kubectl -n ai-networking-demo port-forward service/mock-llm 8080
curl -X POST localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"demo","messages":[{"role":"user","content":"cache me"}]}'
```

Repita o comando para receber `X-Cache-Status: HIT`.

## InferencePool

Com `helm` instalado, o script usa Gateway API `v1.6.0`, GAIE `v1.5.0`, Agentgateway `v1.4.1` e llm-d Router `v0.9.0`.

```bash
./scripts/install-inference.sh
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get gateway,httproute,inferencepool
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo port-forward service/llm-d-inference-gateway 8080:80
```

Em outro terminal, envie um Chat Completion para `http://localhost:8080/v1/chat/completions`. O `HTTPRoute` criado pelo chart encaminha a chamada ao `InferencePool`.

## Egress e quota

O cenário de Egress tem um cliente sem chave, um upstream protegido por `Secret` e uma quota local de 20 tokens por minuto.

```bash
./scripts/install-egress.sh
kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo exec deployment/client-app -- \
  curl -i http://llm-d-inference-gateway.ai-networking-demo.svc.cluster.local/v1/chat/completions \
  -H 'Host: egress.local' \
  -H 'Content-Type: application/json' \
  -d '{"model":"demo","messages":[{"role":"user","content":"token budget test"}]}'
```

O comando não envia `Authorization`. O Agentgateway lê `upstream-api-key` e injeta o token Bearer no upstream. A resposta identifica `external-mock`. Repita a chamada até uma delas retornar `429`.
