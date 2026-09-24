# Plano de implementação: demo de DRA

## Objetivo

Criar uma demonstração independente da demo central de inferência que mostre a alocação de um dispositivo GPU mock e, em extensão opcional, interfaces DRANET a Pods pelo Dynamic Resource Allocation (DRA) no Kind.

## Decisões

- Usar Kubernetes v1.37, Kind e o `dra-example-driver` v0.3.0.
- Reutilizar artefatos publicados pelo driver; não escrever, compilar ou manter código Go do driver.
- Usar templates de GPU e rede e dois Pods consumidores, um por worker, para evidenciar `ResourceSlice`, `DeviceClass`, `ResourceClaim.status.allocation` e os dispositivos preparados em cada Pod.
- Manter scripts, cluster, cache e manifests da demo de inferência sem alteração.
- Instalar DRANET somente pela imagem/manifests oficiais publicados; não escrever ou compilar Go.
- Criar `dranet-dummy0` e `dranet-dummy1` via `docker exec`, uma em cada worker, e alocar uma por Pod para observar `ip addr`.
- Mostrar `dranet0` e os endereços `169.254.10.1/30` e `.2/30`, declarando que os dummies não têm conectividade.
- Não usar RDMA, GPU física ou alegações de desempenho; as interfaces dummy são apenas dispositivos locais da demo.

## Ponto de parada

Antes de instalar o driver, confirmar que há artefato de driver pronto e compatível com Kind. Se a única forma suportada de obtê-lo exigir compilação de Go ou criação de programa próprio, parar e solicitar decisão.

## Índice de trabalho

1. [x] Adicionar configuração e alvos Make independentes para criar o cluster Kind e instalar o driver DRA.
2. [x] Usar a imagem oficial publicada do `dra-example-driver`, sem compilação local.
3. [x] Adicionar manifest combinado: `DeviceClass`, quatro `ResourceClaimTemplate` e dois Pods consumidores.
4. [x] Adicionar validação mínima que confirme a alocação e a preparação do dispositivo mock.
5. [x] Adicionar um alvo separado para aplicar os manifests do workload.
6. [x] Documentar o roteiro de demonstração separado da inferência.
7. [x] Adicionar alvos separados para driver, workload e validação DRANET.
8. [x] Criar interfaces dummy nos workers e validar claims, `dranet0` e endereços sem conectividade.

## Resultado da investigação do driver

O tutorial oficial do Kubernetes documenta a instalação do DaemonSet em Kind e
a imagem pública do driver; a release v0.3.0 do projeto adiciona a imagem
oficial correspondente. O README do projeto `kubernetes-sigs/dra-example-driver`
confirma Kind como plataforma da demo e GPUs mock. Assim, a implementação usa
esse artefato pronto diretamente; não compila, escreve ou mantém código Go do
driver. O chart upstream não é necessário para este recorte mínimo.

Fontes: [tutorial oficial de instalação DRA](https://kubernetes.io/docs/tutorials/cluster-management/install-use-dra/),
[release v0.3.0 do driver](https://github.com/kubernetes-sigs/dra-example-driver/releases/tag/v0.3.0)
e [README do driver de exemplo](https://github.com/kubernetes-sigs/dra-example-driver).

Para DRANET: [README e instalação oficial](https://github.com/kubernetes-sigs/dranet),
[guia de múltiplas redes](https://dranet.sigs.k8s.io/docs/user/gke-multinetwork/)
e [alocação DRA no Kubernetes](https://kubernetes.io/docs/tasks/configure-pod-container/assign-resources/allocate-devices-dra/).
As interfaces dummy dependem de Linux, Docker privilegiado e `ip`; não foram executadas neste ambiente.
