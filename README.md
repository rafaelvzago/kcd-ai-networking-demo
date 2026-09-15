# KCD Brasil 2026: networking para IA

Demo local de inferência com Istio, Gateway API, GAIE, `InferencePool` e llm-d.

## Modelo rápido

Modelo simulado com TTFT menor, atendido por três réplicas no pool `fast`, para evidenciar o balanceamento.

![Modelo rápido](docs/diagrams/flow-fast_happy_path.gif)

## Modelo de qualidade

Modelo simulado com TTFT maior, atendido pelo pool separado `quality`, para evidenciar a seleção de pools.

![Modelo de qualidade](docs/diagrams/flow-quality_happy_path.gif)

## Pool inválido

Um valor de `X-Demo-Pool` diferente de `fast` ou `quality` não corresponde a nenhuma rota e não alcança um `InferencePool`.

![Pool inválido](docs/diagrams/flow-invalid_pool.gif)

## Gerar os diagramas

Use o [FlowStory](https://github.com/noyitz/flowstory). Consulte o [guia rápido](https://github.com/noyitz/flowstory/blob/main/docs/quick-start-prompt.md) e a [referência do schema](https://github.com/noyitz/flowstory/blob/main/CLAUDE.md).

1. Abra `docs/architecture/diagram.json` no FlowStory.
2. Exporte um GIF para cada fluxo: `fast_happy_path`, `quality_happy_path` e `invalid_pool`.
3. Salve-os em `docs/diagrams/` como `flow-fast_happy_path.gif`, `flow-quality_happy_path.gif` e `flow-invalid_pool.gif`.

O JSON é a fonte do diagrama; não há arquivos D2 ou SVG para manter.

## Pré-requisitos

- Docker, Kind, `kubectl` e Helm
- No Linux: `fs.inotify.max_user_instances >= 512`

```bash
sudo sysctl -w fs.inotify.max_user_instances=512
```

## Preparar a demo

Com internet, crie o cache e carregue as imagens no Kind:

```bash
make prepare-offline
```

Em seguida, faça o ensaio usando somente o cache:

```bash
OFFLINE=1 make model-routing
```

Isso instala o Gateway Istio, três simuladores `fast` (TTFT de 100 ms), um `quality` (TTFT de 500 ms) e um `InferencePool` para cada modelo, sem baixar manifests, charts ou imagens.

## Validar

```bash
make validate-model-routing
```

O cliente envia uma API OpenAI-compatível para `/v1/chat/completions`. `X-Demo-Pool: fast|quality` seleciona o `InferencePool`; a validação mostra os pods, `usage` e exige TTFT de `fast` menor que o de `quality`.

## Ensaio offline

Prepare o cache e o cluster antes da palestra. No palco, rode somente:

```bash
make rehearse-offline
```

Esse comando não instala charts, aplica manifests nem baixa imagens.

## Decisão

[ADR-002](docs/adr/0002-uma-demo-kubernetes-com-istio.md) registra o escopo da demonstração.
