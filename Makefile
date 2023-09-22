TMP_REPO=/tmp/hybrid-coolstore

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

include $(BASE)/config.sh

.PHONY: install remote-install clean-remote-install create-aws-credentials install-gitops deploy-gitea create-clusters demo-manual-install argocd argocd-password gitea coolstore-ui topology-view coolstore-a-password metrics alerts generate-orders email remove-lag login-a login-b login-c contexts hugepages f5 verify-f5 installer-image create-bastion-credentials install-with-f5 create-argocd-account create-token deploy-handler add-gitea-webhook

install: create-aws-credentials install-gitops deploy-gitea create-clusters create-argocd-account create-token deploy-handler add-gitea-webhook
	@echo "done"

# This is the same as the above 'install:' rule except the 'create-bastion-credentials' script is a wrapper for 'create-aws-credentials' script. 
# The 'f5-bastion:' rule copies the repo to the bastion and then executes the 'f5:' rule on the bastion.
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
	$(BASE)/scripts/init-gitea $(GIT_PROJ) gitea $(GIT_ADMIN) $(GIT_PASSWORD) $(GIT_ADMIN)@example.com $(TMP_REPO) $(GIT_REPO) 'Demo App'
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


create-argocd-account:
	oc patch argocd/openshift-gitops \
	  -n openshift-gitops \
	  --type merge \
	  -p '{"spec":{"extraConfig":{"accounts.$(ARGO_ACCOUNT)":"login, apiKey"}}}'

	oc get -n openshift-gitops argocd/openshift-gitops -o jsonpath='{.spec.rbac.policy}' \
	| \
	tee /tmp/policy.csv

	echo 'p, $(ARGO_ACCOUNT), applications, sync, default/*, allow' \
	>> \
	/tmp/policy.csv

	cat /tmp/policy.csv | sed 's/$$/\\n/' | tr -d '\n' | sed 's/\\n$$//' > /tmp/policy2.csv

	oc patch argocd/openshift-gitops \
	  -n openshift-gitops \
	  -p '{"spec":{"rbac":{"policy":"'"`cat /tmp/policy2.csv`"'"}}}' \
	  --type merge

	rm -f /tmp/policy.csv /tmp/policy2.csv
	sleep 5


create-token:
	@ARGOHOST="`oc get -n openshift-gitops route/openshift-gitops-server -o jsonpath='{.spec.host}'`"; \
	if [ -z "$$ARGOHOST" ]; then echo "could not retrieve argocd host"; exit 1; fi; \
	echo "argocd host is $$ARGOHOST"; \
	/bin/echo -n "waiting for API to be available..."; \
	while [ -z "`curl -sk https://$$ARGOHOST/api/version 2>/dev/null | jq -r '.Version'`" ]; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done; \
	echo "done"; \
	PASSWORD="`oc get -n openshift-gitops secret/openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' | base64 -d`"; \
	if [ -z "$$PASSWORD" ]; then echo "could not retrieve argocd admin password"; exit 1; fi; \
	echo "argocd admin password is $$PASSWORD"; \
	JWT=`curl -sk -XPOST -H 'Accept: application/json' -H 'Content-type: application/json' --data '{"username":"admin","password":"'"$$PASSWORD"'"}' "https://$$ARGOHOST/api/v1/session" | jq -r '.token'`; \
	if [ -z "$$JWT" ]; then echo "could not retrieve argocd JWT"; exit 1; fi; \
	echo "argocd JWT is $$JWT"; \
	TOKEN=`curl -sk -XPOST -H 'Accept: application/json' -H 'Content-type: application/json' -H "Authorization: Bearer $$JWT" --data '{"id":"$(TOKEN_ID)","name":"'"$(ARGO_ACCOUNT)"'"}' "https://$$ARGOHOST/api/v1/account/$(ARGO_ACCOUNT)/token" | jq -r '.token'`; \
	if [ -z "$$TOKEN" ]; then echo "could not generate token"; exit 1; fi; \
	echo "token is $$TOKEN"; \
	/bin/echo -n "$$TOKEN" > $(TOKEN_FILE)


deploy-handler:
	# this section is not used because of a bug in the ArgoCD certificate
	# - the incorrect service name is used
	#rm -rf /tmp/certs
	#mkdir -p /tmp/certs
	#oc extract -n openshift-gitops secret/argocd-secret --keys=tls.crt --to=/tmp/certs
	#oc create -n $(HANDLER_PROJ) secret generic argocd-sync-certs --from-file=argocd.crt=/tmp/certs/tls.crt
	#oc label -n $(HANDLER_PROJ) secret/argocd-sync-certs app=argocd-sync
	#rm -rf /tmp/certs

	oc create -n $(HANDLER_PROJ) secret generic argocd-sync \
	  --from-file=TOKEN=$(TOKEN_FILE) \
	  --from-literal=APP=$(ARGO_APP) \
	  --from-literal=IGNORECERT=true

	oc label -n $(HANDLER_PROJ) secret/argocd-sync app=argocd-sync

	oc apply -n $(HANDLER_PROJ) -f $(BASE)/yaml/argocd-sync.yaml


add-gitea-webhook:
	@/bin/echo -n "waiting for handler to come up..."
	@HANDLER_HOST="`oc get -n $(HANDLER_PROJ) route/argocd-sync -o jsonpath='{.spec.host}'`"; \
	if [ -z "$$HANDLER_HOST" ]; then \
	  echo "could not get handler host"; \
	  exit 1; \
	fi; \
	while [ "`curl -s http://$$HANDLER_HOST/healthz 2>/dev/null`" != "OK" ]; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"

	$(BASE)/scripts/gitea-webhook \
	  $(GIT_PROJ) \
	  gitea \
	  $(GIT_ADMIN) \
	  $(GIT_PASSWORD) \
	  $(GIT_REPO) \
	  http://argocd-sync.$(HANDLER_PROJ).svc:8080 \
	  push \
	  main


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
	rm -f /tmp/.hub-cluster-details bastion-env.sh

ssh:
	scripts/ssh-bastion

