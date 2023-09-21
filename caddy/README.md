# Caddy Load-Balancer

This directory contains instructions on setting up Caddy as a load-balancer.

01. Provision a Single-Node OpenShift cluster on RHPDS

01. Login using `oc login`

01. Edit the `ConfigMap` in `caddy-openshift-yaml`

	*   Ensure that the domain names for each configuration block (e.g. `coolstore-ui-demo.domain.com`) reflect your DNS domain name
	*   Ensure that all `reverse_proxy` entries point to the provisioned clusters

01. Deploy Caddy to the `caddy` namespace

		oc apply -f caddy-openshift.yaml

01. Get the service external address
		
		./get-external-address

01. Add DNS entries for the following services and map them to the service external address

	*   `cart-demo`
	*   `catalog-demo`
	*   `coolstore-ui-demo`
	*   `inventory-demo`
	*   `order-demo`
