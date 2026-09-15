# Plano de implementação: #10 — ensaio offline

## Objetivo

Permitir preparar, instalar e validar a demo central usando somente artefatos locais. O palco continua executando apenas `make rehearse-offline`.

## Decisões

- A preparação ocorre com internet; a instalação offline recebe `OFFLINE=1`.
- Charts e manifests ficam em um diretório de cache ignorado pelo Git. Imagens são carregadas no Kind durante a preparação.
- Nenhuma credencial é armazenada no cache.

## Índice de trabalho

O trabalho corresponde ao ticket GitHub #10. O ticket não será alterado enquanto a regra de não enviar alterações ao remoto estiver vigente.

### Fase 1: preparar artefatos locais

1. [x] Adicionar `make prepare-offline`.
   - Baixar versões já fixadas do Gateway API e GAIE para `.demo-cache/`.
   - Baixar o chart `llm-d-router-gateway:v0.9.0` para `.demo-cache/`.
   - Garantir localmente as imagens do Istio, simulador e Endpoint Picker e carregá-las no cluster Kind existente.
   - Verificação: falhar com lista clara de artefatos ausentes; confirmar que o cache não contém segredos.

### Fase 2: instalar sem rede

2. [x] Adaptar os instaladores para `OFFLINE=1`.
   - Aplicar os manifests do cache, em vez de URLs GitHub.
   - Usar o chart local, em vez de referência OCI.
   - Manter o comportamento atual como padrão quando `OFFLINE` não estiver definido.
   - Verificação: `OFFLINE=1 make model-routing` não contém chamadas a URL ou OCI e instala os dois pools usando o cache.

### Fase 3: provar o ensaio

3. [ ] Executar a verificação offline reproduzível.
   - Preparar o cache e o cluster enquanto há conectividade.
   - Desconectar a rede externa em um ensaio manual e executar `OFFLINE=1 make model-routing` seguido de `make rehearse-offline`.
   - Verificação: ambos retornam sucesso; `fast` e `quality` chegam aos simuladores corretos.

## Checkpoint final

- [x] Cache contém os manifests, chart e imagens necessários.
- [x] `OFFLINE=1 make model-routing` não busca artefatos remotos.
- [ ] `make rehearse-offline` passa sem rede externa.
- [x] README descreve preparação e roteiro de palco separadamente.

## Riscos

| Risco | Mitigação |
| --- | --- |
| Uma nova imagem indireta do chart falta no cache | Obter a lista de imagens do chart renderizado e validá-la no preparo. |
| Um teste offline bloqueia o acesso ao API server local | Fazer o corte de rede externo manualmente, preservando loopback e a rede Docker. |
