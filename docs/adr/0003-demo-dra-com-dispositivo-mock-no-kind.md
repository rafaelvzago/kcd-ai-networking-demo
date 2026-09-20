# Demo de DRA com dispositivo mock no Kind

**Status:** accepted. A demonstração de DRA será independente da demo central de inferência e usará Kubernetes v1.35 ou superior no Kind com o `dra-example-driver`. Ela mostrará o inventário em `ResourceSlice`, a seleção por `DeviceClass`, a alocação registrada em `ResourceClaim` criado por `ResourceClaimTemplate` e o Pod consumidor; o driver fornece GPU mock.

## Extensão opcional DRANET

DRANET fica em alvos, scripts e manifests separados. A extensão usa a imagem
oficial publicada e interfaces Linux dummy criadas nos dois workers para
demonstrar a mesma sequência DRA para interfaces de rede. Ela não usa RDMA,
não compila Go e não altera o fluxo GPU mock.

O cluster tem um control-plane e dois workers; cada Pod recebe uma `dranet0`
em worker distinto. O script pós-criação usa `docker exec` para criar
`dranet-dummy0` no primeiro worker e `dranet-dummy1` no segundo; DRANET move as interfaces para
os Pods. Claims atribuem `169.254.10.1/30` e `169.254.10.2/30`. A validação
mostra `dranet0`, os endereços, `ResourceSlice` e claims, sem declarar
conectividade. O caminho exige Linux e Docker privilegiado e não foi executado
neste ambiente. A extensão não
representa RDMA nem desempenho, conforme a documentação do
[DRANET](https://github.com/kubernetes-sigs/dranet) e do
[Kubernetes DRA](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/);
ver também [Linux `ip-link`](https://man7.org/linux/man-pages/man8/ip-link.8.html).

Os DaemonSets GPU e DRANET têm afinidade que exclui `control-plane` e `master`,
portanto os `ResourceSlice` da demo são publicados somente pelos workers.
