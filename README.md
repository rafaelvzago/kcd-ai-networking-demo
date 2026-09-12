# KCD Brasil 2026 — Architecture & Product Specifications

Este repositório contém a documentação técnica da demonstração prática para a palestra **“A Evolução do Kubernetes Networking na Era da IA”** no KCD Brasil 2026.

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

Repita o `curl` para observar `X-Cache-Status: HIT`. Para a demonstração completa, os charts oficiais do `llm-d` Router Gateway Mode e do Agentgateway devem ser instalados sobre este cluster; eles fornecem os CRDs e o `InferencePool` que não pertencem ao mock.
