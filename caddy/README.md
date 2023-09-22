# Caddy Load-Balancer

This directory contains instructions on setting up Caddy as a load-balancer.

01. Provision a Single-Node OpenShift cluster on RHPDS

01. Login using `oc login`

01. Edit the `caddy-domains` ConfigMap in `caddy-openshift-yaml`

	*   Set `DNS_DOMAIN` to your DNS domain name
	*   Set `DOMAIN_1`, `DOMAIN_2`, and `DOMAIN_3` to each managed cluster's OpenShift router wildcard domain name (e.g. `apps.my-domain.com`)

01. Deploy Caddy to the `caddy` namespace - note that the StatefulSet is set to `0` replicas initially

		oc apply -f caddy-openshift.yaml

01. Get the service external address
		
		./get-external-address

01. Add DNS entries for the following services and map them to the service external address

	*   `cart-demo`
	*   `catalog-demo`
	*   `coolstore-ui-demo`
	*   `inventory-demo`
	*   `order-demo`

01. Once the DNS entries have been setup, scale the StatefulSet up

		oc scale -n caddy sts/caddy --replicas=1
