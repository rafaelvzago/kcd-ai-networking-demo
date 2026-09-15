.DEFAULT_GOAL := help

.PHONY: help test run image bootstrap inference fast-inference validate-fast-inference model-routing validate-model-routing validate-demo egress demo status diagrams

help:
	@printf '%s\n' \
	  'make test       # testes Go' \
	  'make run        # mock local em :8080' \
	  'make image      # imagem Docker local' \
	  'make bootstrap  # Kind + tres backends' \
	  'make inference  # demo legada: Gateway API, GAIE e llm-d' \
	  'make fast-inference # Istio + llm-d + tres simuladores fast' \
	  'make validate-fast-inference # valida o caminho fast pelo Istio' \
	  'make model-routing          # pools fast e quality pelo Istio' \
	  'make validate-model-routing # valida o roteamento por modelo' \
	  'make validate-demo          # valida toda a demonstracao no Kind' \
	  'make egress     # Secret, client-app e quota de tokens' \
	  'make diagrams   # renderiza os diagramas de arquitetura (requer d2)' \
	  'make demo       # bootstrap + inference + model-routing + egress' \
	  'make status     # recursos da demo no Kind'

test:
	GOCACHE=/tmp/kcd-go-build go test ./...

run:
	go run ./cmd/mock-llm-server

image:
	docker build -t mock-llm-server:dev .

bootstrap:
	./scripts/bootstrap-kind.sh

inference:
	./scripts/install-inference.sh

fast-inference:
	bash ./scripts/install-fast-inference.sh

validate-fast-inference:
	bash ./scripts/validate-fast-inference.sh

model-routing:
	./scripts/install-model-routing.sh

validate-model-routing:
	./scripts/validate-model-routing.sh

validate-demo:
	./scripts/validate-demo.sh

egress:
	./scripts/install-egress.sh

demo: bootstrap inference model-routing egress

status:
	kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get deployments,pods,services,gateway,httproute,inferencepool

diagrams:
	d2 --layout elk docs/architecture/overview.d2 docs/architecture/overview.svg
	d2 --layout elk docs/architecture/request-flows.d2 docs/architecture/request-flows.svg
