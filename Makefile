TMP_REPO=/tmp/hybrid-coolstore

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install remote-install clean-remote-install create-aws-credentials install-gitops deploy-gitea create-clusters demo-manual-install argocd argocd-password gitea coolstore-ui topology-view coolstore-a-password metrics alerts generate-orders email remove-lag login-a login-b login-c contexts hugepages f5 verify-f5 installer-image create-bastion-credentials install-with-f5

install: create-aws-credentials install-gitops deploy-gitea create-clusters
	@echo "done"

# Do the install but also include pre-config steps for later 'make f5'. The script 'create-bastion-credentials' is a drop-in replacement for 'create-aws-credentials''.
install-with-f5: create-bastion-credentials install-gitops deploy-gitea create-clusters f5-bastion
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
	-for s in `oc get clusterrolebinding -o jsonpath='{.items[?(@.subjects[0].name == "remote-installer")].metadata.name}'`; do \
	  oc delete clusterrolebinding $$s; \
	done

create-aws-credentials:
	$(BASE)/scripts/create-aws-credentials

create-bastion-credentials:
	$(BASE)/scripts/create-bastion-credentials

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
	  oc label managedcluster local-cluster cloud-; \
	  oc label managedcluster local-cluster cloud=vmware; \
	  oc apply -f $(BASE)/yaml/acm-gitops/acm-gitops.yaml; \
	  $(BASE)/scripts/create-clusterset; \
	  $(BASE)/scripts/create-clusters; \
	  $(BASE)/scripts/setup-console-banners; \
	  $(BASE)/scripts/setup-letsencrypt; \
	  $(BASE)/scripts/install-submariner; \
	  $(BASE)/scripts/configure-hugepages; \
	  oc apply -f $(BASE)/yaml/argocd/coolstore.yaml; \
	fi
	@# Note we are performing some tasks between cluster provisioning and
	@# installing Submariner in order to give the cluster some time to settle

# installs on a single cluster without ArgoCD
demo-manual-install:
	# ensure we are logged into OpenShift
	oc whoami
	$(BASE)/scripts/oc-apply $(BASE)/yaml/data-grid-operator/ openshift-gitops
	$(BASE)/scripts/oc-apply $(BASE)/yaml/knative/serverless/
	$(BASE)/scripts/oc-apply $(BASE)/yaml/knative/knative/
	$(BASE)/scripts/oc-apply $(BASE)/yaml/kafka/overlays/single-cluster/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/yugabyte/overlays/single-instance/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/order/database/overlays/single-cluster/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/cart/base/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/catalog/base/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/coolstore-ui/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/inventory/base/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/order/app/base/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/services/payment/base/ demo
	$(BASE)/scripts/oc-apply $(BASE)/yaml/kafka-consumer/ demo

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

f5: contexts
	@scripts/configure-f5 --clean f5/hcd-coolstore-multi-cluster.yaml

f5-bastion: 
	@scripts/configure-f5-bastion

verify-f5:
	@scripts/verify-hugepages

installer-image:
	docker build -t $(INSTALLER_IMAGE) $(BASE)/installer-image
	docker push $(INSTALLER_IMAGE)

clean:
	rm -f /tmp/.hub-cluster-details
