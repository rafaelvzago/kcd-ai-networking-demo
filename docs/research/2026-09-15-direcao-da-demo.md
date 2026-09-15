# Pesquisa: direção da demo após feedback

Data: 15 de setembro de 2026. Escopo: pesquisa; nenhuma alteração nos cenários executáveis.

## Decisão recomendada

Não usar Agentgateway como exemplo nem como componente de palco. Para **inferência**, manter uma demonstração Kubernetes baseada em **Istio + Gateway API + Gateway API Inference Extension (GAIE) + llm-d**. Para **egress**, apenas explicar o padrão (credencial fora da aplicação e limite por tokens); se for necessário demonstrá-lo, usar uma configuração separada de **Praxis AI**, fora do fluxo de Gateway API e sem Kubernetes. Não apresentar egress como parte obrigatória da demo ao vivo.

Isso preserva a mensagem central — networking de IA no Kubernetes com Istio — e evita associar a palestra ao produto que o feedback pediu para não promover.

## Inferência: o corte demonstrável

A documentação oficial do Istio traz exatamente o desenho necessário: três réplicas de `llm-d-inference-sim`, um `Gateway` Istio, um `HTTPRoute` cujo backend é um `InferencePool`, e o endpoint picker para escolher backends. O controlador precisa ser instalado com `ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true`. [Istio: Gateway API Inference Extension](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api-inference-extension/)

O guia do próprio llm-d para Istio confirma o mesmo fluxo: Gateway gerenciado pelo Istio, `InferencePool` e `HTTPRoute` para os servidores de modelo, sem depender de Agentgateway. [llm-d: Istio](https://llm-d.ai/docs/infrastructure/gateway/istio)

O simulador do llm-d já elimina a necessidade de evoluir o `mock-llm-server` para esta parte. Ele aceita configuração por flags ou YAML (flags vencem YAML), nome de modelo servido, limite de contexto, concorrência e fila; simula TTFT, latência entre tokens, carga e transferência de KV cache; e pode devolver `X-Request-Id`. [Configuração do llm-d-inference-sim](https://github.com/llm-d/llm-d-inference-sim/blob/main/docs/configuration.md) A documentação de cache detalha que reduções de TTFT por cache só aparecem no cálculo por token, e descreve o caminho prefill/decode desagregado. [KV cache do simulador](https://github.com/llm-d/llm-d-inference-sim/blob/main/docs/kv-cache.md)

**Roteiro mínimo:** três simuladores com perfis diferentes; uma chamada por `model` para mostrar seleção de pool/servidor e uma repetição com prefixo comum para relacionar cache e TTFT. Usar nomes de modelos simulados ou de modelos abertos; não é preciso nem recomendável usar Claude numa demo de roteamento, pois introduz credencial, custo e dependência externa sem ensinar mais sobre o dataplane.

## Praxis: egress isolado, se houver tempo

O repositório oficial do Praxis AI o descreve como componentes para construir um AI Gateway, com filtros para roteamento, tradução de protocolos, injeção de credenciais, contabilização de tokens e guardrails. Seu quick start executa o binário localmente. [Praxis AI README](https://github.com/praxis-proxy/ai/blob/main/README.md) A documentação do projeto lista explicitamente configuração de *rate limit* e injeção de credenciais. [Praxis: configuration overview](https://praxis.fast/docs/configuration/overview/)

Portanto, a demonstração opcional mais curta é: iniciar Praxis localmente, definir a chave do provedor no gateway, fazer um `POST /v1/chat/completions` sem `Authorization` no cliente e observar o limite. Ela deve ser uma seção independente chamada “AI gateway: padrão de egress”, sem Kubernetes, sem Gateway API e sem comparação com Agentgateway. Confirmar a sintaxe e a versão da configuração do Praxis antes de prometer um comando ao vivo.

## Treinamento, DRA e RDMA

O `dra-example-driver` é uma referência para autores de drivers DRA; seu quickstart expõe GPUs **mock** e serve como ponto de partida para um driver próprio. Não demonstra rede nem RDMA. [dra-example-driver README](https://github.com/kubernetes-sigs/dra-example-driver)

Para a história de rede, DRANET é o exemplo diretamente relevante: é um driver de rede Kubernetes que usa DRA, conversa com kubelet via DRA API e com o runtime via NRI, e publica interfaces para seleção por `DeviceClass` e `ResourceClaim`. [DRANET README](https://github.com/kubernetes-sigs/dranet) DRA é estável desde Kubernetes 1.35: `DeviceClass` categoriza dispositivos; `ResourceClaim` os solicita; e `ResourceSlice` representa o inventário publicado pelo driver. [Kubernetes: DRA API objects](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/dra-api/)

O conteúdo substancial de RDMA não é “rodar uma chamada LLM mais rápido” em Kind. É mostrar a alocação declarativa conjunta/topology-aware de GPU e NIC RDMA para um job distribuído, então observar o `ResourceClaim` resolvido e a interface RDMA atribuída. DRANET documenta GPUDirect RDMA em GKE A3 Ultra/A4 e expõe oito NICs RDMA no exemplo; isso exige hardware/cluster adequado. [DRANET: GKE e GPUDirect RDMA](https://github.com/kubernetes-sigs/dranet/blob/main/site/content/docs/user/gke-rdma.md) Como corte para a palestra, explicar os manifests e a relação GPU↔NIC é honesto; só executar a demo se houver ambiente RDMA real. O exemplo genérico de driver DRA não deve ser vendido como prova de RDMA.

## Runtime: Agent Substrate

O projeto correto parece ser **Agent Substrate** (`agent-substrate/substrate`), não o antigo `substrate.dev` de blockchain. É um runtime Kubernetes para muitos atores stateful: multiplexa atores sobre workers pré-aquecidos, suspende/retoma com snapshots e oferece isolamento por microVM ou gVisor. O próprio projeto declara desenvolvimento inicial e APIs sem garantia de compatibilidade. [Agent Substrate README](https://github.com/agent-substrate/substrate)

Vale como tópico de encerramento (“o runtime de agentes é outro plano da pilha”), não como quarto cenário. Sua demo oficial de contador já introduz actores, worker pools, snapshots e rede própria; adicioná-la desviaria do tema de networking para inferência e DRA/RDMA. [Counter demo](https://github.com/agent-substrate/substrate/tree/main/demos/counter)

## Etapas já fechadas no repositório

As issues fechadas mostram uma sequência coerente, mas também revelam onde o feedback exige revisão:

1. [#1](https://github.com/rafaelvzago/kcd-ai-networking-demo/issues/1) fixou Kind, Gateway API/GAIE/llm-d Router e Agentgateway; #2 criou o mock local; [#3](https://github.com/rafaelvzago/kcd-ai-networking-demo/issues/3) tornou o bootstrap reproduzível sem registry.
2. [#4](https://github.com/rafaelvzago/kcd-ai-networking-demo/issues/4) definiu InferencePool, três backends, distribuição entre prompts e afinidade de cache sem prometer round-robin.
3. [#5](https://github.com/rafaelvzago/kcd-ai-networking-demo/issues/5) definiu egress: cliente sem chave, `Secret` no gateway e quota pós-resposta com 429.

O primeiro corte futuro deve substituir o componente de inferência por Istio onde ele aparece, preservando InferencePool/HTTPRoute e os critérios de distribuição. O segundo deve retirar o egress Agentgateway do roteiro principal; a versão Praxis, se feita, é um experimento independente. Só depois disso vale decidir se RDMA terá ambiente real. Agent Substrate fica apenas como material explicativo.

## Itens explicitamente adiados

- Integração com Claude ou qualquer provedor externo.
- Um quarto runtime ou uma demo de Agent Substrate.
- “Demo RDMA” em Kind ou sem NIC/GPU compatíveis.
- Mapeamento dinâmico de `ServiceAccount` para credenciais.

Adicionar cada item somente quando houver objetivo de palco, ambiente e tempo de ensaio definidos.
