BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install demo-manual-install argocd argocd-password gitea coolstore-ui topology-view coolstore-a-password metrics alerts generate-orders email remove-lag

install:
	$(BASE)/scripts/install-gitops
	$(BASE)/scripts/clean-gitea
	$(BASE)/scripts/deploy-gitea
	$(BASE)/scripts/init-gitea $(GIT_PROJ) gitea $(GIT_ADMIN) $(GIT_PASSWORD) $(GIT_ADMIN)@example.com yaml coolstore 'Demo App'
	$(BASE)/scripts/configure-gitops

demo-manual-install:
	# ensure we are logged into OpenShift
	oc whoami
	oc new-project $(PROJ) || oc project $(PROJ)
	cd $(BASE)/yaml/helm && helm template -n $(PROJ) amq-streams amq-streams-0.1.0.tgz | oc apply -f -
	oc apply -f $(BASE)/yaml/knative/serverless/serverless-operator.yaml
	$(BASE)/scripts/install-nexus
	$(BASE)/scripts/wait-for-api knativeservings
	oc apply -f $(BASE)/yaml/knative/knative/knative-serving.yaml
	$(BASE)/scripts/wait-for-api knativeeventings
	oc apply -f $(BASE)/yaml/knative/knative/knative-eventing.yaml
	$(BASE)/scripts/wait-for-api knativekafkas
	oc apply -f $(BASE)/yaml/knative/knative/knative-kafka.yaml
	$(BASE)/scripts/wait-for-api kafkas
	$(BASE)/scripts/wait-for-api kafkatopics
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka/kafka.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka/orders-topic.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/kafka/payments-topic.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/cart/cart.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/catalog/catalog.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/coolstore-ui/coolstore-ui.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/inventory/inventory.yaml
	oc apply -n $(PROJ) -f $(BASE)/yaml/services/order/order.yaml
	$(BASE)/scripts/wait-for-api kafkasources
	$(BASE)/scripts/wait-for-crd services.serving.knative.dev
	cd $(BASE)/yaml/helm && helm template -n $(PROJ) payment payment-0.1.0.tgz | oc apply -f -

argocd:
	@open "https://`oc get -n openshift-gitops route/openshift-gitops-server -o jsonpath='{.spec.host}'`"

argocd-password:
	@oc get -n openshift-gitops secret/openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 -d && echo

gitea:
	@open "https://`oc get -n $(GIT_PROJ) route/gitea -o jsonpath='{.spec.host}'`/$(GIT_ADMIN)/coolstore"

coolstore-ui:
	@$(BASE)/scripts/open-coolstore-ui

topology-view:
	@CONSOLE=`oc get mcl/coolstore-a -o json 2>/dev/null | jq -r '.status.clusterClaims[] | select (.name=="consoleurl.cluster.open-cluster-management.io") | .value'`; \
	if [ -z "$$CONSOLE" ]; then \
	  CONSOLE="`oc get route/console -n openshift-console -o jsonpath='{.spec.host}'`"; \
	  if [ -n "$$CONSOLE" ]; then \
	    CONSOLE="https://$$CONSOLE"; \
	  else \
	    echo "error: could not get OpenShift Console URL"; exit 1; \
	  fi; \
	fi; \
	open "$${CONSOLE}/topology/ns/$(PROJ)"

coolstore-a-password:
	@oc get secrets -n coolstore-a -l hive.openshift.io/secret-type=kubeadmincreds -o jsonpath='{.items[].data.password}' | base64 -d
	@echo

metrics:
	@CONSOLE=`oc get mcl/coolstore-a -o json 2>/dev/null | jq -r '.status.clusterClaims[] | select (.name=="consoleurl.cluster.open-cluster-management.io") | .value'`; \
	if [ -z "$$CONSOLE" ]; then \
	  CONSOLE="`oc get route/console -n openshift-console -o jsonpath='{.spec.host}'`"; \
	  if [ -n "$$CONSOLE" ]; then \
	    CONSOLE="https://$$CONSOLE"; \
	  else \
	    echo "error: could not get OpenShift Console URL"; exit 1; \
	  fi; \
	fi; \
	open "$${CONSOLE}/"'/dev-monitoring/ns/$(PROJ)/metrics?query0=kafka_consumergroup_lag_sum%7B%7D'

alerts:
	@CONSOLE=`oc get mcl/coolstore-a -o json 2>/dev/null | jq -r '.status.clusterClaims[] | select (.name=="consoleurl.cluster.open-cluster-management.io") | .value'`; \
	if [ -z "$$CONSOLE" ]; then \
	  CONSOLE="`oc get route/console -n openshift-console -o jsonpath='{.spec.host}'`"; \
	  if [ -n "$$CONSOLE" ]; then \
	    CONSOLE="https://$$CONSOLE"; \
	  else \
	    echo "error: could not get OpenShift Console URL"; exit 1; \
	  fi; \
	fi; \
	open "$${CONSOLE}/dev-monitoring/ns/$(PROJ)/alerts"

# Generate 10 orders - run this after killing the payment service
generate-orders:
	@oc apply -n $(PROJ) -f $(BASE)/yaml/order-generator/order-generator-job.yaml
	@sleep 30
	@oc delete -n $(PROJ) -f $(BASE)/yaml/order-generator/order-generator-job.yaml

email:
	@# Namespace is hardcoded to demo
	@open "https://`oc get -n demo route/maildev-web -o jsonpath='{.spec.host}'`"

remove-lag:
	@oc rsh -n $(PROJ) my-cluster-kafka-0 bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --group knative-group --topic orders --timeout-ms 10000
