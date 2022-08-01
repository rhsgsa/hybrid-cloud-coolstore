# Hybrid Cloud Coolstore Demo

## Installation

01. Provision an ACM Hub cluster in RHPDS

01. Login to OpenShift as `cluster-admin` using `oc login`

01. Install services - this will: install the OpenShift GitOps operator, install `gitea`, upload manifests to `gitea`, setup a `coolstore` Application that points to the manifests in `gitea` (app-of-apps pattern)

		make install

01. Create credentials for AWS named `aws` in the ACM console

01. Create a cluster set named `coolstore`

	* Create a namespace binding to `openshift-gitops` - with this in place, ACM will create secrets in the `openshift-gitops` namespace for each cluster in the clusterset

01. Create an AWS cluster in the `coolstore` cluster set named `coolstore-a`

	|Network|CIDR|
	|---|---|
	|Cluster network|`10.128.0.0/14`|
	|Service network|`172.30.0.0/16`|

01. Create an AWS cluster in the `coolstore` cluster set named `coolstore-b`

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

01. Provision all services to `coolstore-a`

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-a-cluster-secret \
		  kafka=true \
		  cart=true \
		  catalog=true \
		  coolstore-ui=true \
		  inventory=true \
		  knative=true \
		  order=true \
		  payment=true

01. Provision OpenShift Serverless to `coolstore-b` - this is avoid a long wait when we move the `payment` service to `coolstore-b` later

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-b-cluster-secret \
		  knative=true


## Demo

01. Login to the ArgoCD UI,

	*   Get the ArgoCD admin password

			make argocd-password

	*   Open a browser to the ArgoCD UI - login as `admin` with the password from the previous step; do not login with `OpenShift Login` - your user will have a read-only role even if you are logged in as a `cluster-admin`

			make argocd

01. Walk through all the services deployed to the `coolstore-a` cluster in the Applications screen

01. Login to gitea with `demo` / `password`

		make gitea

01. Walk through the manifests in gitea, starting with the `argocd` directory

01. Login to the `coolstore-a` topology view to look at all the components deployed

	*   Get the `coolstore-a` `kubeadmin` password

			make coolstore-a-password

	*   Opena browser to the `coolstore-a` topology view - login with `kubeadmin` as the username

			make topology-view

01. To test the demo app,

		make coolstore-ui

	* Add an item to the shopping cart
	* Select `Cart` / `Checkout`
	* Enter your details and click `Checkout` - [ensure that your credit card number starts with `4`](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/blob/c32daed7aa7c803b1a29fbe56be350bf4a5e6be2/m4/payment-service/src/main/java/com/redhat/cloudnative/PaymentResource.java#L61)
	* Select the `Orders` tab - you should see a new order with a payment status of `PROCESSING`
	* If you look at the Topology View, you should see the `payment` Knative service spinning up
	* After a few seconds, reload the orders page, and the order's payment status should be set to `COMPLETED`

01. To get an overview of all the deployed services, access the Topology View in the `demo` project on the OpenShift Console

		make topology-view


## Move `payment` to another cluster

01. Deploy `payment` service to `coolstore-b`

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-b-cluster-secret \
		  payment=true

01. You should be able to see the `coolstore-b-payment` Application being rolled out in the ArgoCD UI

01. After `payment` has been deployed to `coolstore-b-payment`, remove `payment` from `coolstore-a`

		oc label \
		  -n openshift-gitops \
		  secret/coolstore-a-cluster-secret \
		  payment-

01. You should see the `coolstore-a-payment` Application disappear from the ArgoCD UI

01. Perform another transaction on the `coolstore-ui` - the order should be processed by the `payment` service even though it is now residing on another cluster

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
