# KCD Brasil 2026: networking para IA

Demo local de inferência com Istio, Gateway API, GAIE, `InferencePool` e llm-d.

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

O cliente envia uma API OpenAI-compatível para `/v1/chat/completions`. `X-Demo-Pool: fast|quality` seleciona o `InferencePool`; a resposta mostra `x-inference-pod`, `usage` e TTFT.

## Ensaio offline

Prepare o cache e o cluster antes da palestra. No palco, rode somente:

```bash
make rehearse-offline
```

Esse comando não instala charts, aplica manifests nem baixa imagens.

## Decisão

[ADR-002](docs/adr/0002-uma-demo-kubernetes-com-istio.md) registra o escopo da demonstração.
