# ADR-001: Arquitetura da Demonstração Prática de Networking de IA no Kubernetes (KCD Brasil 2026)

**Status:** Aprovado
**Data:** 12 de Setembro de 2026
**Autores:** Palestrantes (KCD Brasil 2026)
**Contexto do Evento:** KCD São Paulo 2026 (Palestra: *A Evolução do Kubernetes Networking na Era da IA*)

---

## 1. Contexto e problema

A palestra de 30 minutos no KCD Brasil 2026 precisa de uma demonstração dos dois temas de rede para IA apresentados:

1. **Inferência (State-Aware Routing & InferencePool)**: Roteamento inteligente de requisições de inferência considerando contexto, estado do backend e simulação de *KV Cache HIT/MISS* utilizando a **Gateway API** (`InferencePool` / `llm-d`).
2. **Egress Gateway & Governança de IA**: Interceptação de chamadas de workloads para modelos externos (ex.: OpenAI `/v1/chat/completions`), injeção segura de API Keys via `ServiceAccount` e aplicação de *token rate limit*.

### Restrições

- LLMs reais, como vLLM, Ollama e modelos do HuggingFace, pedem GPUs ou consomem CPU e memória demais para a demonstração. A latência também pode variar durante a palestra.
- A apresentação trata de decisões de rede, roteamento L7/L8 e governança. O processamento de GPU não faz parte da demonstração.

---

## 2. Decisão de arquitetura

Vamos usar um servidor de modelo simulado (*Mock Model Server*) em Python com FastAPI, empacotado em um container leve. Os manifestos Kubernetes cobrem a Gateway API e o Egress Gateway.

### Componentes

1. **Mock Model Server (`mock-llm-server`)**
   - Expõe o endpoint `/v1/chat/completions`.
   - Aceita cabeçalhos HTTP (`X-Simulate-Delay-MS`, `X-Cache-Status`) e parâmetros no payload para alterar o comportamento da resposta.
   - Retorna uma resposta de LLM sintética com metadados de consumo de tokens.
2. **Gateway API + InferencePool (`llm-d`)**
   - Implantação de 3 réplicas do `mock-llm-server`.
   - A Gateway API aplica uma política de `InferencePool` para demonstrar distribuição baseada em estado e métricas.
3. **Egress AI Gateway (Istio / extensão da Gateway API)**
   - O Pod cliente envia requisições sem API Key no código.
   - O Egress Gateway valida a identidade do Pod via `ServiceAccount` do Kubernetes, injeta o cabeçalho `Authorization: Bearer <API_KEY>` e aplica regras de *token rate limiting*.

---

## 3. Justificativa e alternativas consideradas

### Alternativas

- **Alternativa A: Rodar uma LLM real com vLLM / Ollama**
  - *Desvantagem:* Exige GPUs caras ou consome CPU e memória demais no laptop do palestrante. A demonstração pode ficar indisponível ou levar dezenas de segundos para responder.
- **Alternativa B: Utilizar apenas a API oficial da OpenAI diretamente**
  - *Desvantagem:* Depende de internet estável, pode consumir a cota real da chave e não permite simular o comportamento interno de inferência, como o *KV Cache* no cluster.

### Escolha: servidor simulado (*mock*) e Kubernetes Gateway API

- Roda em qualquer cluster Kind ou Minikube local com menos de 500 MB de RAM.
- Produz respostas rápidas e previsíveis durante a palestra.
- Exercita a camada de controle e de dados da rede: Gateway API, Istio, ServiceAccount e Egress.

---

## 4. Consequências

### Benefícios

- A demonstração é rápida e pode rodar em qualquer ambiente de desenvolvimento.
- A aplicação chama a API; a infraestrutura de rede trata de autorização, roteamento e métricas de IA.

### Limitação conhecida

- A demonstração não executa inferência em GPU. O slide de introdução deixará isso claro para a audiência.
