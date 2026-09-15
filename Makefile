.DEFAULT_GOAL := help

.PHONY: help prepare-offline fast-inference validate-fast-inference model-routing validate-model-routing rehearse-offline status

help:
	@printf '%s\n' \
	  'make prepare-offline         # baixa artefatos e imagens antes do palco' \
	  'make fast-inference          # Istio + llm-d + tres simuladores fast' \
	  'make validate-fast-inference # valida o caminho fast pelo Istio' \
	  'make model-routing           # pools fast e quality pelo Istio' \
	  'make validate-model-routing  # valida o roteamento por X-Demo-Pool' \
	  'make rehearse-offline         # valida a demo sem instalar ou baixar nada' \
	  'make status                   # recursos da demo no Kind'

prepare-offline:
	bash ./scripts/prepare-offline.sh

fast-inference:
	bash ./scripts/install-fast-inference.sh

validate-fast-inference:
	bash ./scripts/validate-fast-inference.sh

model-routing:
	bash ./scripts/install-model-routing.sh

validate-model-routing:
	bash ./scripts/validate-model-routing.sh

rehearse-offline:
	OFFLINE=1 bash ./scripts/install-model-routing.sh
	bash ./scripts/validate-model-routing.sh

status:
	kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get deployments,pods,services,gateway,httproute,inferencepool
