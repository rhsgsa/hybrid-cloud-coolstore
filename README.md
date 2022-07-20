# Hybrid Cloud Coolstore Demo

To install,

01. Login to OpenShift as `cluster-admin` using `oc login`

01. Install services - this will: install the OpenShift GitOps operator, install `gitea`, upload manifests to `gitea`, setup a `coolstore` Application that points to the manifests in `gitea` (app-of-apps pattern)

		make install

01. To login to the ArgoCD UI,

	*   Get the ArgoCD admin password

			make argocd-password

	*   Open a browser to the ArgoCD UI - login as `admin` with the password from the previous step; do not login with `OpenShift Login` - your user will have a read-only role even if you are logged in as a `cluster-admin`

01. To access `gitea` - login with `demo` / `password`

		make gitea

01. To test the demo app,

		make coolstore-ui

01. To get an overview of all the deployed services, access the Topology View in the `demo` project on the OpenShift Console


## Updating Helm Charts

The `amq-streams` operator installation manifests and the `payment` service have been packaged as Helm Charts in the `yaml/helm` directory.

If you wish to make any changes to the Helm Charts,

01. Extract the `.tgz` file, make any necessary changes

01. Package up the chart - e.g. `helm package payment`

01. Regenerate `index.yaml`: `helm repo index .`


## Resources

* [Solution git repo](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/tree/ocp-4.9/m4)

* [Lab instructions](http://guides-m4-labs-infra.6923.rh-us-east-1.openshiftapps.com/workshop/cloudnative/lab/high-performing-cache-services)
