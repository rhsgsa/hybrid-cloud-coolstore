BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install demo-manual-install argocd argocd-password gitea coolstore-ui topology-view

install:
	$(BASE)/scripts/install-gitops
	$(BASE)/scripts/deploy-gitea
	$(BASE)/scripts/init-gitea $(GIT_PROJ) gitea $(GIT_ADMIN) $(GIT_PASSWORD) $(GIT_ADMIN)@example.com yaml coolstore 'Demo App'
	$(BASE)/scripts/configure-gitops

demo-manual-install:
	# ensure we are logged into OpenShift
	oc whoami
	oc new-project $(PROJ) || oc project $(PROJ)
	oc apply -f $(BASE)/yaml/operators/kafka-operator.yaml
	oc apply -f $(BASE)/yaml/operators/serverless-operator.yaml
	$(BASE)/scripts/install-nexus
	$(BASE)/scripts/wait-for-api knativeservings
	oc apply -f $(BASE)/yaml/knative/knative-serving.yaml
	$(BASE)/scripts/wait-for-api knativeeventings
	oc apply -f $(BASE)/yaml/knative/knative-eventing.yaml
	$(BASE)/scripts/wait-for-api knativekafkas
	oc apply -f $(BASE)/yaml/knative/knative-kafka.yaml
	$(BASE)/scripts/wait-for-api kafkas
	$(BASE)/scripts/wait-for-api kafkatopics
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka/kafka.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/cart.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/catalog.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/coolstore-ui.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/inventory.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/order.yaml
	$(BASE)/scripts/wait-for-api kafkasources
	$(BASE)/scripts/wait-for-crd services.serving.knative.dev
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/payment.yaml

argocd:
	@open "https://`oc get -n openshift-gitops route/openshift-gitops-server -o jsonpath='{.spec.host}'`"

argocd-password:
	@oc get -n openshift-gitops secret/openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 -d && echo

gitea:
	@open "https://`oc get -n $(GIT_PROJ) route/gitea -o jsonpath='{.spec.host}'`"

coolstore-ui:
	@open "http://`oc get -n $(PROJ) route/coolstore-ui -o jsonpath='{.spec.host}'`"

topology-view:
	@open "https://`oc get -n openshift-console route/console -o jsonpath='{.spec.host}'`/topology/ns/$(PROJ)"
