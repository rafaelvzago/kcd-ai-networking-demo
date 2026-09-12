# Arquitetura

Os arquivos `.d2` são a fonte de verdade. Gere os SVGs para o README com:

```bash
make diagrams
```

- `overview.d2` mostra o que o `make demo` instala no Kind e como os componentes se relacionam.
- `request-flows.d2` mostra os caminhos de inferência, roteamento por modelo e egress.

Mantenedores e agentes: mudanças de arquitetura, manifests Kubernetes, fluxos de rede ou integrações exigem atualizar o D2 correspondente e regenerar os SVGs. Não edite SVGs manualmente.
