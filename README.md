# Hybrid Cloud Coolstore Demo

## Multicluster

### Multicluster Installation

01. Provision an ACM Hub cluster in RHPDS - All Services / OpenShift Workshop / OCP4 ACM Hub

01. Login to the ACM Hub Cluster as `cluster-admin` using `oc login`

01. Install services to the ACM Hub Cluster - this will: install the OpenShift GitOps operator, install `gitea`, upload manifests to `gitea`, setup a `coolstore` Application that points to the manifests in `gitea` (app-of-apps pattern)

		make install

01. Create credentials for AWS named `aws` in the `open-cluster-management` namespece in the ACM console

01. Create a cluster set named `coolstore`

	* Create a namespace binding to `openshift-gitops`

01. Create an AWS cluster in the `coolstore` clusterset named `coolstore-a`

	|Network|CIDR|
	|---|---|
	|Cluster network|`10.128.0.0/14`|
	|Service network|`172.30.0.0/16`|

01. Create an AWS cluster in the `coolstore` clusterset named `coolstore-b`

	|Network|CIDR|
	|---|---|
	|Cluster network|`10.132.0.0/14`|
	|Service network|`172.31.0.0/16`|

01. After both clusters have been provisioned, edit the `coolstore` clusterset and install Submariner add-ons in both clusters

01. Wait for the submariner add-ons to complete installation on both nodes

01. The coolstore services are provisioned based on labels

	|Components|Label|
	|---|---|
	|`amq-streams`, `kafka`|`kafka: "true"`|
	|`cart`|`cart: "true"`|
	|`catalog`|`catalog: "true"`|
	|`coolstore-ui`|`coolstore-ui: "true"`|
	|`inventory`|`inventory: "true"`|
	|`knative`, `openshift-serverless`|`knative: "true"`|
	|`order`|`order: "true"`|
	|`payment`|`payment: "true"`|

01. Provision all services (except `payment`) to `coolstore-a`

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-a-cluster-secret \
		  kafka=true \
		  cart=true \
		  catalog=true \
		  coolstore-ui=true \
		  inventory=true \
		  knative=true \
		  order=true

01. Provision OpenShift Serverless and the `payment` service to `coolstore-b`

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-b-cluster-secret \
		  knative=true \
		  payment=true

01. Add banners to the OpenShift Consoles so you know which cluster you're on - do this for the hub cluster, `coolstore-a`, `coolstore-b`

		apiVersion: console.openshift.io/v1
		kind: ConsoleNotification
		metadata:
		  name: my-banner
		spec:
		  text: Hub Cluster
		  location: BannerTop 

01. Modify the `coolstore-a` alert manager settings so that alert emails are sent quicker

	* Open a browser to the `coolstore-a` OpenShift Console
	* Administrator / Administration / Cluster Settings / Configuration / Alertmanager / YAML
	* Change `group_interval` to `15s`
	* Change `group_wait` to `15s`

01. Open the following browser tabs

	* ArgoCD
		* `make argocd-password` to get the `admin` password
		* `make argocd` will open a browser to ArgoCD - login as `admin`

	* `gitea` - `make gitea`, login as `demo` / `password`

	* `coolstore-a` OpenShift Console topology view in the `demo` project

	* `coolstore-b` OpenShift Console topology view in the `demo` project

	* `coolstore-ui` - `make coolstore-ui` to open a browser

	* `maildev` - `make email`

	* Hub cluster OpenShift Console secrets screen in the `openshift-gitops` project


### Multicluster Demo Part 1

01. Switch to the ArgoCD browser tab - walk through all the services deployed to the `coolstore-a` cluster in the Applications screen

01. Show how `payment` is deployed to `coolstore-b`

01. Switch to the `gitea` browser tab - walk through the manifests in gitea, starting with the `argocd` directory

01. Switch to the `coolstore-a` OpenShift Console browser tab and open the `demo` project's  topology view

01. Switch to the browser tab showing `coolstore-b`'s OpenShift Console `demo` project topology view - point out how the `payment` service is deployed as a serverless component

01. Test the demo app

	* Switch to the `coolstore-ui` browser tab
	* Add an item to the shopping cart
	* Select `Cart` / `Checkout`
	* Enter your details and click `Checkout` - [ensure that your credit card number starts with `4`](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/blob/c32daed7aa7c803b1a29fbe56be350bf4a5e6be2/m4/payment-service/src/main/java/com/redhat/cloudnative/PaymentResource.java#L61)
	* Select the `Orders` tab - you should see a new order with a payment status of `PROCESSING`
	* If you look at the Topology View, you should see the `payment` Knative service spinning up
	* After a few seconds, reload the orders page, and the order's payment status should be set to `COMPLETED`

01. Switch to the QR code tab, and invite the audience to submit their own orders

	
### Meanwhile in the background - this is to be performed by someone else

01. Make sure you're logged into the hub cluster with `oc login`

01. After the order's payment status has been set to `COMPLETED`, remove the `payment` service

	* Either shutdown the `coolstore-b` cluster
	* Or undeploy `payment` from `coolstore-b`

			oc label \
			  -n openshift-gitops \
			  secret/coolstore-b-cluster-secret \
			  payment-

01. Generate a few orders

		make generate-orders

01. This should trigger the high consumer lag alert in a few minutes


### Multicluster Demo Part 2

01. Switch to the `coolstore-ui` orders screen and show how the number of orders are increasing, but the order status is stuck at `PROCESSING` - talk about how something's happened to the `payment` service
 
01. After about a minute, the high consumer lag alert should be triggered - switch to the maildev browser tab; you should receive an email notifying you of the alert

01. Switch to the `coolstore-a` OpenShift Console tab, click on Observe / Alerts and show how the alert has been triggered

01. Switch to the Metrics tab / Custom query / `kafka_consumergroup_lag_sum` - show how the value has spiked, showing a lag between producers and consumers, indicating that something has gone wrong with the `payment` service

01. Move the `payment` service to `coolstore-a`

	* Switch to the hub cluster OpenShift Console secrets screen, edit the `coolstore-a-cluster-secret` secret, add `payment=true` as a label

	* Switch to the `coolstore-a` OpenShift Console tab, click on the topology view - show how the `payment` service is deployed and spun up

	* After about a minute, the `payment` service should be up - switch back to the `coolstore-ui` browser tab, open up the orders screen, and watch the orders complete the payment phase


### Cleaning Up

Before you destroy the clusters,

* Uninstall submariner from `coolstore-a` and `coolstore-b`
* Remove them from the `coolstore` clusterset

If you don't do the above, the clusters may be stuck inthe detaching phase. If this happens to you, [refer to this article](https://access.redhat.com/solutions/6243371).


## Single Cluster Installation

01. Provision an OpenShift 4.10 workshop cluster on RHPDS

01. Login to the cluster as a `cluster-admin`

01. Install the OpenShift GitOps operator and `gitea`

		make install

01. Open a browser to `gitea`

		make gitea

01. Select the `coolstore` repo

01. Edit `argocd/kafka.yaml` and set `.kafka.serviceexport` in `.spec.template.spec.source.helm` to `false`

01. Edit `argocd/payment.yaml` and set `.payment.kafka.bootstrapServers` in `.spec.template.spec.source.helm` to `my-cluster-kafka-bootstrap.demo.svc.cluster.local:9092`

01. Create a cluster secret for the `in-cluster` cluster

		cat << EOF | oc apply -f -
		apiVersion: v1
		kind: Secret
		metadata:
		  name: in-cluster-secret
		  namespace: openshift-gitops
		  labels:
		    argocd.argoproj.io/secret-type: cluster
		    cart: "true"
		    catalog: "true"
		    coolstore-ui: "true"
		    inventory: "true"
		    kafka: "true"
		    knative: "true"
		    order: "true"
		    payment: "true"
		type: Opaque
		stringData:
		  name: in-cluster
		  server: https://kubernetes.default.svc
		  config: |
		    {
		      "bearerToken": "$(oc whoami -t)",
		      "tlsClientConfig": {
		        "insecure": true
		      }
		    }
		EOF
---

## Updating Helm Charts

The `amq-streams` operator installation manifests and the `payment` service have been packaged as Helm Charts in the `yaml/helm` directory.

If you wish to make any changes to the Helm Charts,

01. Extract the `.tgz` file, make any necessary changes

01. Package up the chart - e.g. `helm package payment`

01. Regenerate `index.yaml`: `helm repo index .`


## Troubleshooting

*   If you have trouble connecting to Kafka from the remote cluster, spin up a test Kafka pod to access `my-cluster-kafka-bootstrap.demo.svc.clusterset.local`

		apiVersion: v1
		kind: Pod
		metadata:
		  creationTimestamp: null
		  labels:
		    run: client
		  name: client
		spec:
		  containers:
		  - command:
		    - tail
		    - -f
		    - /dev/null
		    image: registry.redhat.io/amq7/amq-streams-kafka-31-rhel8@sha256:c113eefe89a40c96e190a24bcdf1b0823865e3c80ffb883bc8ed4b7bb2661df6
		    name: client
		    resources: {}
		  dnsPolicy: ClusterFirst
		  restartPolicy: Always


## Resources

* [Solution git repo](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/tree/ocp-4.9/m4)

* [Lab instructions](http://guides-m4-labs-infra.6923.rh-us-east-1.openshiftapps.com/workshop/cloudnative/lab/high-performing-cache-services)

* [Strimzi advertised addresses](https://strimzi.io/docs/operators/latest/configuring.html#property-listener-config-broker-reference)
