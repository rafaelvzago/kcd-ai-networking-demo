# Pesquisa: DRA em Kind com dispositivo de exemplo

Data: 20 de setembro de 2026. Escopo: viabilidade e desenho mínimo; nenhum cluster, instalação ou manifesto foi executado.

## Veredito

É viável demonstrar Dynamic Resource Allocation (DRA) em Kind com um dispositivo de exemplo e uma interface de rede alocados a Pods. A demo usa o [`kubernetes-sigs/dra-example-driver`](https://github.com/kubernetes-sigs/dra-example-driver) para a prova GPU mock e o [`kubernetes-sigs/dranet`](https://github.com/kubernetes-sigs/dranet) para a prova de interface. A evidência correta é a alocação registrada nos `ResourceClaim`s, as variáveis `GPU_DEVICE_*` e `ip addr` dentro dos Pods; não se deve anunciar GPU física, RDMA, desempenho ou conectividade entre interfaces dummy. [README do driver de exemplo](https://github.com/kubernetes-sigs/dra-example-driver#creating-a-cluster-and-installing-the-example-driver) [workloads de exemplo](https://github.com/kubernetes-sigs/dra-example-driver#run-example-workloads-shared-across-kind-and-gke)

## Como DRA funciona no recorte da demo

O driver publica o inventário em `ResourceSlice`; um `DeviceClass` define os dispositivos elegíveis; um `ResourceClaim` (ou um `ResourceClaimTemplate` por Pod) pede o dispositivo; o Pod referencia esse claim. O scheduler escolhe um dispositivo e nó elegíveis e grava a alocação no claim; então kubelet e driver fazem a preparação local antes de o container iniciar. [Como DRA funciona](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/how-dra-works/) [uso de claims em Pods](https://kubernetes.io/docs/tasks/configure-pod-container/assign-resources/allocate-devices-dra/) [operações do driver no nó](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/dra-features/)

## Versão e gates

Usar Kind com Kubernetes **v1.35 ou superior**. DRA é estável desde v1.35 e o gate base `DynamicResourceAllocation` ficou bloqueado como habilitado; configurá-lo não é necessário nem produz efeito. Em v1.34 ou anterior, DRA ainda requer configuração de versão/gates e não é adequado para uma demo previsível. [estado da funcionalidade](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/) Não são necessários gates ou recursos experimentais (por exemplo, *device binding conditions* ou operações opcionais de nó) para o caso básico. [recursos DRA](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/dra-features/)

## Corte mínimo recomendado

1. Um cluster Kind com control-plane e um worker, Kubernetes >=1.35.
2. Uma instância do `dra-example-driver`, no perfil padrão de GPU mock.
3. Um único workload simples baseado em `basic-resourceclaimtemplate` do repositório.
4. No terminal, mostrar: `ResourceSlice` publicado; `ResourceClaim.status.allocation`; Pod em `Running`; e `GPU_DEVICE_*` nos logs do container.

Esse corte demonstra descoberta, seleção, alocação pelo scheduler e preparação DRA sem depender de GPU, NIC ou RDMA reais. `ResourceClaimTemplate` é preferível aqui porque Kubernetes cria e gerencia o claim por Pod; `ResourceClaim` manual serve quando o dispositivo precisa sobreviver ao Pod ou ser compartilhado. [semântica de claims](https://kubernetes.io/docs/tasks/configure-pod-container/assign-resources/allocate-devices-dra/)

## DRANET: extensão de interface sem RDMA

O [`kubernetes-sigs/dranet`](https://github.com/kubernetes-sigs/dranet) documenta Kind com nós v1.37 e permite selecionar interfaces por `DeviceClass` e `ResourceClaim`. É um driver de rede: fala com o kubelet pela API DRA, usa NRI para falar com o runtime e configura a *network namespace* do Pod. A implementação mantém essa extensão em alvos e manifests próprios para que a prova GPU continue independente. [Quick start do DRANET](https://dranet.sigs.k8s.io/docs/quick-start/) [arquitetura do DRANET](https://github.com/kubernetes-sigs/dranet#how-it-works)

Um script pós-criação usa `docker exec` para criar `dranet-dummy0` no primeiro
worker e `dranet-dummy1` no segundo. O DRANET publica as interfaces e aloca uma por
Pod; claims renomeiam-nas para `dranet0` e atribuem `169.254.10.1/30` e
`.2/30`. A validação mostra `ResourceSlice`, claims, `dranet0` e endereços,
sem Service ou tráfego entre os dummies. Fontes: [Linux
`ip-link`](https://man7.org/linux/man-pages/man8/ip-link.8.html) e [interfaces
Linux no DRANET](https://dranet.sigs.k8s.io/docs/concepts/linux-network-interfaces/).

O script depende de Linux, Docker com os workers Kind privilegiados e da
ferramenta `ip`; a criação não foi executada neste ambiente.
Continua fora do escopo qualquer RDMA, bridge adicional, CNI alternativo ou
medição de desempenho.
