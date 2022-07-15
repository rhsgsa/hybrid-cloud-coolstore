# CCN Module 4

To install,

01. Login to OpenShift using `oc login`

01. Install services

		make install

Note: Some of the manifests (`payment.yaml` and `kafka-operator.yaml`) assume that we are deploying into the `demo` namespace - they should be converted to use a Helm chart.

The Java services (`cart`, `catalog`, `inventory`, `order`) are built from source using Source-to-Image. All the S2I builds use `nexus` as a maven mirror. You will probably want to comment that out for an actual deployment.

The `payment` service is a Quarkus native app and is deployed from a [pre-built image](https://github.com/orgs/rhsgsa/packages/container/package/payment-native).

The `coolstore-ui` service is a Node.js service that can't be built from S2I (the build process requires Python and the keycloak dependency needs to be removed) so it is also deployed from a [pre-built image](https://github.com/orgs/rhsgsa/packages/container/package/coolstore-ui).


## Fix for shopping cart service compilation error

```
mvn quarkus:add-extension -Dextensions="messaging-kafka"
```

## Resources

* [Solution git repo](https://github.com/RedHat-Middleware-Workshops/cloud-native-workshop-v2-labs-solutions/tree/ocp-4.9/m4)

* [Lab instructions](http://guides-m4-labs-infra.6923.rh-us-east-1.openshiftapps.com/workshop/cloudnative/lab/high-performing-cache-services)
