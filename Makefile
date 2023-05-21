TMP_REPO=/tmp/hybrid-coolstore

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install remote-install clean-remote-install create-aws-credentials install-gitops deploy-gitea create-clusters demo-manual-install argocd argocd-password gitea coolstore-ui topology-view coolstore-a-password metrics alerts generate-orders email remove-lag login-a login-b login-c contexts hugepages f5 verify-f5 installer-image

install: create-aws-credentials install-gitops deploy-gitea create-clusters
	@echo "done"

remote-install: create-aws-credentials clean-remote-install
	oc new-project $(REMOTE_INSTALL_PROJ) || oc project $(REMOTE_INSTALL_PROJ)
	oc create -n $(REMOTE_INSTALL_PROJ) sa remote-installer
	oc adm policy add-cluster-role-to-user -n $(REMOTE_INSTALL_PROJ) cluster-admin -z remote-installer
	oc create -n $(REMOTE_INSTALL_PROJ) cm remote-installer-config --from-file=$(BASE)/config.sh
	oc apply -f $(BASE)/yaml/remote-installer/remote-installer.yaml
	@/bin/echo -n "waiting for job to appear..."
	@until oc get -n $(REMOTE_INSTALL_PROJ) job/remote-installer 2>/dev/null >/dev/null; do \
	  /bin/echo -n "."; \
	  sleep 10; \
	done
	@echo "done"
	oc wait -n $(REMOTE_INSTALL_PROJ) --for condition=ready po -l job-name=remote-installer
	oc logs -n $(REMOTE_INSTALL_PROJ) -f job/remote-installer

clean-remote-install:
	-oc delete -n $(REMOTE_INSTALL_PROJ) job/remote-installer
	-oc delete -n $(REMOTE_INSTALL_PROJ) sa/remote-installer
	-oc delete -n $(REMOTE_INSTALL_PROJ) cm/remote-installer-config
	-oc delete clusterrolebinding `oc get clusterrolebinding -o jsonpath='{.items[?(@.subjects[0].name == "remote-installer")].metadata.name}'`

create-aws-credentials:
	$(BASE)/scripts/create-aws-credentials

install-gitops:
	$(BASE)/scripts/install-gitops

deploy-gitea:
	$(BASE)/scripts/clean-gitea
	$(BASE)/scripts/deploy-gitea
	$(BASE)/scripts/clone-from-template $(BASE)/yaml $(TMP_REPO)
	$(BASE)/scripts/init-gitea $(GIT_PROJ) gitea $(GIT_ADMIN) $(GIT_PASSWORD) $(GIT_ADMIN)@example.com $(TMP_REPO) coolstore 'Demo App'
	rm -rf $(TMP_REPO)

create-clusters:
	@if ! oc get project open-cluster-management 2>/dev/null >/dev/null; then \
	  echo "this cluster does not have ACM installed"; \
	  oc apply -f $(BASE)/yaml/single-cluster-rbac/clusterrolebinding.yaml; \
	  oc apply -f $(BASE)/yaml/single-cluster/coolstore.yaml; \
	else \
	  echo "this cluster has ACM installed"; \
	  oc apply -f $(BASE)/yaml/acm-gitops/acm-gitops.yaml; \
	  $(BASE)/scripts/create-clusterset; \
	  $(BASE)/scripts/create-clusters; \
	  $(BASE)/scripts/wait-for-secrets; \
	  $(BASE)/scripts/setup-console-banners; \
	  $(BASE)/scripts/setup-letsencrypt; \
	  $(BASE)/scripts/configure-hugepages; \
	  $(BASE)/scripts/install-submariner; \
	  oc apply -f $(BASE)/yaml/argocd/coolstore.yaml; \
	fi
	@# Note we are performing some tasks between cluster provisioning and
	@# installing Submariner in order to give the cluster some time to settle

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
	@$(BASE)/scripts/generate-orders

email:
	@$(BASE)/scripts/open-maildev

remove-lag:
	@oc rsh -n $(PROJ) my-cluster-kafka-0 bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --group knative-group --topic orders --timeout-ms 10000

login-a:
	@echo "oc login --insecure-skip-tls-verify `oc get -n openshift-gitops secret/coolstore-a-cluster-secret -o jsonpath='{.data.server}' | base64 -d` --token `oc get -n openshift-gitops secret/coolstore-a-cluster-secret -o jsonpath='{.data.config}' | base64 -d | jq -r '.bearerToken'`"

login-b:
	@echo "oc login --insecure-skip-tls-verify `oc get -n openshift-gitops secret/coolstore-b-cluster-secret -o jsonpath='{.data.server}' | base64 -d` --token `oc get -n openshift-gitops secret/coolstore-b-cluster-secret -o jsonpath='{.data.config}' | base64 -d | jq -r '.bearerToken'`"

login-c:
	@echo "oc login --insecure-skip-tls-verify `oc get -n openshift-gitops secret/coolstore-c-cluster-secret -o jsonpath='{.data.server}' | base64 -d` --token `oc get -n openshift-gitops secret/coolstore-c-cluster-secret -o jsonpath='{.data.config}' | base64 -d | jq -r '.bearerToken'`"

contexts:
	@scripts/set-contexts

f5:
	@scripts/configure-f5 f5/hcd-coolstore-multi-cluster.yaml

verify-f5:
	@scripts/verify-hugepages

installer-image:
	docker build -t $(INSTALLER_IMAGE) $(BASE)/installer-image
	docker push $(INSTALLER_IMAGE)
