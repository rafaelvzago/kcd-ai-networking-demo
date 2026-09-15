# KCD AI Networking Demo

Vocabulário da demonstração de networking para IA do KCD Brasil 2026.

## Linguagem

**Demo central**:
O único cenário Kubernetes executado ao vivo: inferência com Istio, Gateway API, GAIE e `InferencePool`.
_Evitar_: demo principal, cenário de egress

**Modo offline**:
A forma suportada de executar a demo central sem acesso à internet, usando imagens e artefatos preparados localmente.
_Evitar_: instalação que baixa dependências no palco

**Prova de roteamento**:
A evidência exibida no terminal: modelo solicitado, instância selecionada e TTFT retornados pela API.
_Evitar_: dashboard obrigatório

**Ensaio**:
A validação prévia que cria o cluster, prepara os artefatos offline e confirma a demo central; não é executada no palco.
_Evitar_: instalação diante da audiência

**Demo opcional**:
Uma demonstração independente adiada até a demo central estar ensaiada; PRaxis para o padrão de AI Gateway é a candidata atual.
_Evitar_: parte da demo central

**Simulador de inferência**:
O `llm-d-inference-sim` é o servidor da demo central; reproduz respostas OpenAI-compatíveis e sinais configuráveis de inferência sem exigir GPU.
_Evitar_: servidor mock, modelo real

**API compatível com OpenAI**:
O contrato local de `POST /v1/chat/completions` usado pela demo; ele não implica chamada, credencial ou conta da OpenAI.
_Evitar_: API real da OpenAI

**Inference Payload Processor (IPP)**:
O componente do llm-d que lê o campo `model` da requisição e seleciona o `InferencePool` correspondente.
_Evitar_: transformação proprietária de JSON

**Modelo rápido**:
O modelo simulado com TTFT menor, servido por três réplicas e selecionado pelo pool `fast` para tornar visível o balanceamento.
_Evitar_: backend-1, modelo padrão

**Modelo de qualidade**:
O modelo simulado com TTFT maior, servido por um pool separado para tornar visível o roteamento por modelo.
_Evitar_: backend-3

**Explicação técnica**:
Conteúdo mostrado por arquitetura, manifestos ou fluxo, sem promessa de execução ao vivo; RDMA usa este formato até haver hardware compatível.
_Evitar_: demo RDMA

**Bloco de treinamento**:
A explicação de DRA, DRANET e RDMA que acompanha a palestra, sem uma segunda demo executável.
_Evitar_: cenário de treinamento ao vivo
