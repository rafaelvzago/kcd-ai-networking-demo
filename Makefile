.DEFAULT_GOAL := help

.PHONY: help test run image bootstrap inference model-routing validate-model-routing egress demo status

help:
	@printf '%s\n' \
	  'make test       # testes Go' \
	  'make run        # mock local em :8080' \
	  'make image      # imagem Docker local' \
	  'make bootstrap  # Kind + tres backends' \
	  'make inference  # Gateway API, GAIE, Agentgateway e llm-d' \
	  'make model-routing          # pools demo-fast e demo-quality' \
	  'make validate-model-routing # valida o roteamento por modelo' \
	  'make egress     # Secret, client-app e quota de tokens' \
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

model-routing:
	./scripts/install-model-routing.sh

validate-model-routing:
	./scripts/validate-model-routing.sh

egress:
	./scripts/install-egress.sh

demo: bootstrap inference model-routing egress

status:
	kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get deployments,pods,services,gateway,httproute,inferencepool
