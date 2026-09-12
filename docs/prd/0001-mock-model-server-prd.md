# PRD: Suíte de Demonstração Prática de Networking de IA para Kubernetes (KCD Brasil 2026)

**Versão:** 1.0
**Data:** 12 de Setembro de 2026
**Evento:** KCD São Paulo 2026
**Objetivo:** Especificar os requisitos funcionais e técnicos para a aplicação mock e infraestrutura de rede para a palestra sobre Networking de IA no Kubernetes.

---

## 1. Visão geral do produto

A suíte reúne microsserviços e configurações Kubernetes para demonstrar como a rede atende workloads de IA nas fases de inferência e egress/governança.

---

## 2. Escopo dos componentes

A solução tem três entregáveis:

1. **`mock-llm-server`**: Aplicação Python (FastAPI) em container Docker que emula o endpoint OpenAI `/v1/chat/completions`.
2. **Cenário 1: Inferência (`InferencePool` / Gateway API)**: Manifestos Kubernetes para subir 3 réplicas do servidor simulado e expô-las via Gateway API com extensão de inferência (`llm-d`).
3. **Cenário 2: Egress AI Gateway**: Manifestos e scripts para demonstrar injeção de credenciais baseada em `ServiceAccount` e *token rate limit*.

---

## 3. Requisitos funcionais (FR)

### FR-1: Mock Model Server (`mock-llm-server`)

- **FR-1.1**: O servidor deve expor o endpoint `POST /v1/chat/completions` compatível com o formato de requisição e resposta da OpenAI.
- **FR-1.2**: Deve permitir injetar latência artificial via cabeçalho HTTP `X-Simulate-Delay-MS` ou parâmetro JSON.
- **FR-1.3**: Deve retornar o cabeçalho HTTP `X-Cache-Status` com valores `HIT` ou `MISS` para simular reuso de *KV Cache*.
- **FR-1.4**: O payload de resposta deve conter a seção `usage` com contagem sintética de `prompt_tokens`, `completion_tokens` e `total_tokens`.
- **FR-1.5**: O servidor deve aceitar variável de ambiente `INSTANCE_NAME` para identificação da réplica na resposta.

### FR-2: Roteamento de Inferência (`InferencePool` / Gateway API)

- **FR-2.1**: Deve distribuir requisições entre as réplicas `backend-1`, `backend-2` e `backend-3`.
- **FR-2.2**: Deve permitir demonstrar o roteamento baseado nos metadados da requisição (modelo solicitado, estado de cache).

### FR-3: Egress Gateway & Governança de API Keys

- **FR-3.1**: O Pod cliente (`client-app`) deve enviar uma chamada para `/v1/chat/completions` **sem** incluir o cabeçalho `Authorization`.
- **FR-3.2**: O Egress Gateway deve interceptar a chamada, verificar a `ServiceAccount` do Pod e injetar o cabeçalho `Authorization: Bearer <SECRET_KEY>`.
- **FR-3.3**: O Egress Gateway deve monitorar a contagem de tokens informada na resposta e bloquear requisições subsequentes caso o limite estipulado por minuto seja excedido com HTTP `429 Too Many Requests`.

---

## 4. Requisitos não funcionais (NFR)

- **NFR-1 (Pegada de Recursos):** O servidor mock deve consumir no máximo 50 MB de RAM por réplica e 0,1 vCPU.
- **NFR-2 (Compatibilidade Local):** Todos os manifestos devem rodar sem modificação em clusters locais Kind ou Minikube Kubernetes v1.30+.
- **NFR-3 (Tempo de Execução):** A demonstração completa dos dois cenários no terminal deve ser concluída em menos de 3 minutos.
- **NFR-4 (Portabilidade):** O código deve ser 100% contido no repositório da palestra para fácil reprodução pela comunidade após o evento.

---

## 5. Plano de teste da demonstração ao vivo

| Passo | Comando / Ação | Resultado Esperado |
| :--- | :--- | :--- |
| **1. Inferência** | `curl -H "X-Simulate-Delay-MS: 100" http://gateway.local/v1/chat/completions` | Resposta do `backend-1` com `X-Cache-Status: HIT` |
| **2. Load Balancing** | Loop de 5 requisições `curl` | Distribuição entre as 3 réplicas simuladas |
| **3. Egress OK** | `kubectl exec client-pod -- curl http://egress-gateway/v1/chat/completions` | Chamada bem-sucedida (API Key injetada pelo Gateway) |
| **4. Rate Limit** | Chamada com payload de alto volume de tokens | Retorno `429 Rate Limit Exceeded` pelo Egress |
