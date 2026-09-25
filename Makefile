.DEFAULT_GOAL := help

.PHONY: help prepare-offline fast-inference validate-fast-inference model-routing validate-model-routing rehearse-offline check-dra-prereqs dra-driver dra-workload dra-demo validate-dra-demo dranet-driver dranet-workload dranet-demo validate-dranet-demo status

help:
	@printf '%s\n' \
	  'make prepare-offline         # baixa artefatos e imagens antes do palco' \
	  'make fast-inference          # Istio + llm-d + tres simuladores fast' \
	  'make validate-fast-inference # valida o caminho fast pelo Istio' \
	  'make model-routing           # pools fast e quality pelo Istio' \
	  'make validate-model-routing  # valida o roteamento por X-Demo-Pool' \
	  'make rehearse-offline         # valida a demo sem instalar ou baixar nada' \
	  'make check-dra-prereqs        # verifica Kind 0.33.x antes da demo DRA' \
	  'make dra-driver               # cria o Kind e instala o driver DRA' \
	  'make dra-workload             # aplica os manifests da demo DRA' \
	  'make dra-demo                 # instala drivers e aplica os dois Pods' \
	  'make validate-dra-demo        # valida GPU mock nos dois Pods' \
	  'make dranet-driver            # prepara dummies nos dois workers e instala DRANET' \
	  'make dranet-workload          # aloca interfaces DRANET em dois Pods' \
	  'make dranet-demo              # executa dranet-driver e dranet-workload' \
	  'make validate-dranet-demo     # valida claims, ResourceSlice, dranet0 e IPs; sem conectividade' \
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

check-dra-prereqs:
	@command -v yq >/dev/null 2>&1 || { echo 'Pré-requisito ausente: instale yq para compactar os YAMLs da demo DRA.'; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo 'Pré-requis ausente: instale o Kind v0.33.x antes de executar a demo DRA.'; exit 1; }
	@version="$$(kind version 2>/dev/null | sed -n 's/^kind v\([0-9][^ ]*\).*/\1/p')"; \
	case "$$version" in \
	  0.33.[0-9]*) ;; \
	  *) echo "Versão incompatível do Kind: $${version:-desconhecida}; a demo DRA exige 0.33.x."; exit 1 ;; \
	esac

dra-driver: check-dra-prereqs
	bash ./scripts/install-dra-demo.sh

dra-workload: dranet-driver
	bash ./scripts/apply-dra-workload.sh

dra-demo: dra-workload

validate-dra-demo:
	bash ./scripts/validate-dra-demo.sh

dranet-driver: dra-driver
	bash ./scripts/install-dranet-demo.sh

dranet-workload: dra-workload

dranet-demo: dranet-workload

validate-dranet-demo:
	bash ./scripts/validate-dranet-demo.sh

status:
	kubectl --context kind-kcd-ai-networking-demo -n ai-networking-demo get deployments,pods,services,gateway,httproute,inferencepool
