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
	* Enter your details and click `Checkout`
	* Select the `Orders` tab - you should see a new order with a payment status of `PROCESSING`
	* If you look at the Topology View, you should see the `payment` Knative service spinning up
	* After a few seconds, reload the orders page, and the order's payment status should be set to `COMPLETED`

01. To get an overview of all the deployed services, access the Topology View in the `demo` project on the OpenShift Console

		make topology-view


## Moving `payment` to Another Cluster

### Create credentials to the remote cluster

01. While you are connected to the remote cluster,

		./scripts/generate-cluster-secret remote-cluster \
		  > /tmp/remote-cluster-secret.yaml

01. Connect back to the ArgoCD cluster, then create the secret

		oc apply \
		  -n openshift-gitops \
		  -f /tmp/remote-cluster-secret.yaml

01. In the ArgoCD UI, select the gear icon / Clusters - you should see an entry for `remote-cluster`


## Install OpenShift Serverless, Knative Serving, Knative Eventing, and `payment` to the remote cluster

### Note: This flow needs to be reworked - ArgoCD isn't able to cleanly remove OpenShift Serverless and Knative; we should just remove `payment.yaml` from the `argocd` folder and create a separate directory for the remote cluster

01. Login to the `gitea` web interface, select `demo/coolstore` / `argocd` / `openshift-serverless.yaml` / Edit File

01. Remove `.spec.destination.server`

01. Set `.spec.destination.name` to `remote-cluster`

01. It should look like this

		...
		spec:
		  destination:
		    name: remote-cluster
		  project: default
		...

01. Commit the change

01. Repeat the steps above for `knative.yaml` and `payment.yaml`

01. While you're editing `payment.yaml`, you will also need to configure `.spec.source.helm.values.payment.kafka.bootstrapServers` to point to Kafka on the first cluster

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
