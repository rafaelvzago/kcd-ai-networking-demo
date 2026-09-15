# Pesquisa: CI no `main` e ensaio offline

Data: 15 de setembro de 2026. Escopo: recomendação; nenhum workflow ou script foi alterado.

## Diagnóstico

O workflow atual (`.github/workflows/validate-demo.yml`) só usa `pull_request`. Ele executa `make model-routing` e depois `make rehearse-offline`, mas este último é somente `scripts/validate-model-routing.sh`: não define `OFFLINE=1`, não prepara `.demo-cache` e não cria os recursos a partir desse cache. Portanto ele valida a instalação online e duas requisições, não o ensaio offline.

`scripts/prepare-offline.sh` baixa os manifests e charts para `.demo-cache`, mas carrega as imagens apenas no nó Kind existente. Isso funciona no mesmo cluster, porém não produz um cache de imagens reutilizável entre VMs novas. GitHub-hosted runners recebem uma VM nova por job; logo não se pode pressupor imagens Docker nem `.demo-cache` de uma execução anterior. [GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners) [Dependency caching](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching)

Os manifests usam tags fixas, não `:latest`; Kubernetes usa `IfNotPresent` como política padrão nesse caso, e o kubelet não baixa uma imagem já presente. Declarar `imagePullPolicy: IfNotPresent` torna essa condição explícita. [Kubernetes: image pull policy](https://kubernetes.io/docs/concepts/containers/images/)

## Mudança mínima recomendada

1. No workflow, trocar o gatilho por:

   ```yaml
   on:
     push:
       branches: [main]
     pull_request:
   ```

   GitHub permite múltiplos eventos e o filtro `push.branches` limita a execução a `main`. [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#on)

2. Separar a instalação normal do ensaio offline em dois jobs. O job normal continua com `make model-routing` e validação. O job offline deve, em uma **única VM**, fazer: criar Kind; `make prepare-offline` enquanto há rede; guardar também as imagens como arquivos (`docker save`) sob `.demo-cache/images`; recriar um cluster limpo; restaurar essas imagens com `docker load` e `kind load image-archive`; então rodar `OFFLINE=1 make model-routing` e `make validate-model-routing`. Kind suporta carregar um arquivo de imagem no cluster. [Kind: loading an image](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster)

3. Para provar a propriedade offline, bloquear egress depois do pré-carregamento, mas permitir loopback e a rede interna Docker/Kind, antes do comando `OFFLINE=1`. Sem essa barreira, um pull acidental ainda pode passar e o teste só mostra que o caminho `OFFLINE` foi selecionado. O bloqueio deve ser removido em um passo `if: always()` para preservar upload de logs e cleanup.

4. Não usar `actions/cache` como pré-requisito de correção: um cache pode faltar e ser removido por expiração/limite. Ele só pode acelerar `.demo-cache` entre runs, com chave que inclua os scripts, manifests e versões de imagens/charts. Nunca guardar segredos ali; PRs de fork podem ler caches do escopo da branch padrão. [Cache reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) Para transferência entre dois jobs da mesma execução, usar artifact, não cache. [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)

## Critério de aceite

O job offline começa a instalação em um cluster sem workloads instalados, com egress bloqueado, termina `OFFLINE=1 make model-routing` e passa `make validate-model-routing`. Uma falha por imagem, chart ou manifesto ausente deve falhar o job; isso demonstra que todos os insumos foram pré-carregados.

## Corte deliberado

Não recomendo persistir imagens Docker inteiras em Actions Cache: além do limite/evicção, o cache é otimização e não uma garantia. Para a prova correta, pré-carregar e consumir as imagens na mesma VM; use artefatos somente se separar os jobs for realmente necessário.
