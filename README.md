# Hybrid Cloud Coolstore Demo

To install,

01. Login to OpenShift as `cluster-admin` using `oc login`

01. Install services - this will: install the OpenShift GitOps operator, install `gitea`, upload manifests to `gitea`, setup a `coolstore` Application that points to the manifests in `gitea` (app-of-apps pattern)

		make install

01. To login to the ArgoCD UI,

	*   Get the ArgoCD admin password

			make argocd-password

	*   Open a browser to the ArgoCD UI - login as `admin` with the password from the previous step; do not login with `OpenShift Login` - your user will have a read-only role even if you are logged in as a `cluster-admin`

			make argocd

01. To access `gitea` - login with `demo` / `password`

		make gitea

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


## Moving `payment` to Another Cluster

### Modify Kafka to be accessible from other clusters

01. Provision another cluster, and setup Submariner in both clusters

01. Login to `gitea` with `demo` / `password`

01. Edit `kafka/kafka.yaml` - replace it with the contents from [`kafka-submariner/kafka.yaml`](yaml/kafka-submariner/kafka.yaml); this file sets up extra services and exports them

01. Login to ArgoCD, select the `kafka` application, click on `Refresh`


### Create credentials to the remote cluster

01. While you are connected to the remote cluster,

		./scripts/generate-cluster-secret remote-cluster \
		  > /tmp/remote-cluster-secret.yaml

01. Connect back to the ArgoCD cluster, then create the secret

		oc apply \
		  -n openshift-gitops \
		  -f /tmp/remote-cluster-secret.yaml

01. In the ArgoCD UI, select the gear icon / Clusters - you should see an entry for `remote-cluster`


### Install OpenShift Serverless, Knative Serving, Knative Eventing, and `payment` to the remote cluster

01. Login to the `gitea` web interface (as `demo` / `password`), select `demo/coolstore` / `remote-coolstore`

01. Examine the manifests in that directory - point out how `.spec.destination.name` has been set to `remote-cluster` for `remote-openshift-serverless.yaml`, `remote-knative.yaml`, `remote-payment.yaml`; `remote-coolstore.yaml` still points to `in-cluster` because the child `Application` resources need to reside on the ArgoCD cluster

01. `remote-payment.yaml` also points to the Kafka service on another cluster

01. Configure ArgoCD to deploy to the remote cluster

		oc apply -f ./yaml/remote-coolstore/remote-coolstore.yaml

01. Point your browser to the Topology View of the `demo` namespace in the second cluster - you should see the payment service being deployed after a few minutes

01. After the payment service has been deployed on the second cluster, remove the payment service from the first cluster

	*   Login to `gitea`, select `argocd` / `payment.yaml` - delete the file

01. Login to the ArgoCD UI, select Manage your applications / `coolstore` / REFRESH


## Updating Helm Charts

The `amq-streams` operator installation manifests and the `payment` service have been packaged as Helm Charts in the `yaml/helm` directory.

If you wish to make any changes to the Helm Charts,

01. Extract the `.tgz` file, make any necessary changes

01. Package up the chart - e.g. `helm package payment`

01. Regenerate `index.yaml`: `helm repo index .`


## Resources

* [Solution git repo](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/tree/ocp-4.9/m4)

* [Lab instructions](http://guides-m4-labs-infra.6923.rh-us-east-1.openshiftapps.com/workshop/cloudnative/lab/high-performing-cache-services)

* [Strimzi advertised addresses](https://strimzi.io/docs/operators/latest/configuring.html#property-listener-config-broker-reference)
