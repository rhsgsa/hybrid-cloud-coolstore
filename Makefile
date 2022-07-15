BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install

install:
	# ensure we are logged into OpenShift
	oc whoami
	oc new-project $(PROJ) || oc project $(PROJ)
	oc create -n $(PROJ) -f $(BASE)/yaml/kafka-operator.yaml
	oc create -f $(BASE)/yaml/serverless-operator.yaml
	$(BASE)/scripts/install-nexus
	$(BASE)/scripts/wait-for-api knativeservings
	oc apply -f $(BASE)/yaml/knative-serving.yaml
	$(BASE)/scripts/wait-for-api knativeeventings
	oc apply -f $(BASE)/yaml/knative-eventing.yaml
	$(BASE)/scripts/wait-for-api knativekafkas
	oc apply -f $(BASE)/yaml/knative-kafka.yaml
	$(BASE)/scripts/wait-for-api kafkas
	$(BASE)/scripts/wait-for-api kafkatopics
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/cart.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/catalog.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/coolstore-ui.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/inventory.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/order.yaml
	$(BASE)/scripts/wait-for-api kafkasources
	$(BASE)/scripts/wait-for-crd services.serving.knative.dev
	oc apply -n $(PROJ) -f $(BASE)/yaml/payment.yaml
