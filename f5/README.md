# Configure F5 Distributed Cloud (F5 XC) Global Load Balancer 

## Steps to set up F5 XC for the coolstore hybrid cloud demo

### One time setup 

If this is your first time, follow these steps:

1. Log into the F5 XC Console with your pre-registered Red Hat email address. If needed, ask the f5-asean team for access.
    1. https://f5-asean.console.ves.volterra.io/ - log in or reset your password. Use your Red Hat email as login. 
1. Install vesctl CLI. 
    1. To run on RHEL, be sure to turn off SELinux, otherwise vesctl will crash/core dump on startup.  Use 'sudo setenforce 0'. 
    1. Go to this [F5 XC page](https://f5-asean.console.ves.volterra.io/web/workspaces/administration/personal-management/api_credentials) to create an API Certificate. 
    1. See below example on how to configure the '$HOME/.vesconfig' file. 
    1. See https://gitlab.com/volterra.io/vesctl/blob/main/README.md for all the details on installing vesctl. 
1. The existing F5 UID in the file f5/hcd-coolstore-multi-cluster.yaml should still be valid.  If it is not valid (e.g. the F5 XC pods cannot register with F5), create a new F5 UID and replace it in the config file.  See below docs on how to do this.

Example configuration for vesctl

1. Log into the F5 XC UI, create & download an API Certificate (p12) file and configure the $HOME/.vesconfig file like this:
1. Go to this [F5 XC page](https://f5-asean.console.ves.volterra.io/web/workspaces/administration/personal-management/api_credentials) to create an 'API Certificate'. Download the (p12) file and configure the $HOME/.vesconfig file like this:

Example config:
```
server-urls: https://f5-asean.console.ves.volterra.io/api
p12-bundle: /home/user/path-to/f5-asean.console.ves.volterra.io.api-creds.p12
```

Set the VES_P12_PASSWORD env variable with the password you set when creating your ' API Certificate', e.g.:
```
export VES_P12_PASSWORD=password
```

---
Once all clusters are up.  The steps to set up F5 XC are as follows: 

1. Run 'make f5' from this repo's top level directory. 

After completion of 'make f5', wait 1-2 mins and you should now have F5 configured and working with the Coolstore app. 


# Miscellaneous Notes

## Create all F5 XC sites (ingress points)

1. Log into the Hub cluster and run 'make contexts'. 
1. Copy one of the config files f5/hcd*yaml, e.g. cp f5/hcd-coolstore-multi-cloud.yaml f5/hcd-my-config-file.yaml' and edit the file.  Make changes to the configuration to match your application's ingress needs.  There are comments in the config file to help you. 
1. For all clusters, bring up the initial F5 'sites' (all pods in ves-system namespace) 
  1. Run the command 'scripts/configure-f5 f5/hcd-my-config-file.yaml'.
1. Wait for the site to register with F5 XC.
1. The generated pending 'site registration' is approved automatically.
1. Configure health checks, origin pools and http load balancers for all sites.

How to fetch the CLI:

```
# For MacOS
curl -LO "https://vesio.azureedge.net/releases/vesctl/$(curl -s https://downloads.volterra.io/releases/vesctl/latest.txt)/vesctl.darwin-amd64.gz"

# For Linux
curl -LO "https://vesio.azureedge.net/releases/vesctl/$(curl -s https://downloads.volterra.io/releases/vesctl/latest.txt)/vesctl.linux-amd64.gz"
```

# Reference documentation

- Main OCP instructions: https://docs.cloud.f5.com/docs/integrations/integrating-cloud-mesh-with-ocp
- Additional help: https://f5cloud.zendesk.com/hc/en-us/articles/4410470282263-How-to-create-Customer-Edge-CE-site-on-OpenShift-cluster 
- Get the vesctl CLI: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
- The original site template: https://gitlab.com/volterra.io/volterra-ce/-/raw/master/k8s/ce_k8s.yml
- Generic Kubernetes site creation: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site
- Article about F5 XC Architecture: https://medium.com/volterra-io/managing-thousands-of-edge-kubernetes-clusters-with-gitops-82121f97dfeb

Note: The above instructions mention configuring "Huge Pages" support.  In testing it was found that Huge Pages are needed, otherwise the 'ver-0' pod stay 'Pending'!

# Domain delegation

## One time tasks to set up the domains for each demo and the F5 UID

1. Set up [domain delegation in F5 XC](https://docs.cloud.f5.com/docs/how-to/app-networking/domain-delegation) for the domains you want to use.
    1.  Note that some domains have already been set up for use, e.g.:
        1.  hcd1.ltsai.com
        1.  hcd2.ltsai.com
        1.  hcd3.ltsai.com
        1.  hcd1.bylo.de
        1.  hcd2.bylo.de
        1.  hcd3.bylo.de

# Troubleshooting

If a site does not register with F5, then check out the logs from the vp-manager-0, e.g.:

```
oc --context login-a -n ves-system logs vp-manager-0
```

If you see this error (or similar) in the logs of vp-manager-0, contact F5 XC supprot: 

```
client.go:181: Sending registration request to https://register.ves.volterra.io/registerBootstrap
client.go:188: Unable to parse registration error: unexpected end of JSON input
register.go:701: Registration failed: Registration request: Request Register failed: Response with non-OK status code: 503, content: , retry in 1m4.037955274s
checker.go:184: Starting check for new workload version, with timeout 40m0s
checker.go:109: Workload check has finished without error, sleeping for 5m18.801242383s, until 2023-07-11 07:58:48.595412013 +0000 UTC m=+644.686690212
ipchange.go:35: Unable to read fabric IP from registration: Error reading registration object file: open /etc/vpm/registration-obj.yml: no such file or directory
```
- This disruption has happened twice before, whenever F5 "upgrade their systems".  Examples: 
  - Registration not changing state (NEW -> PENDING -> ADMITTED -> ONLINE) properly
  - Sites stick in "upgrading"

URL for pending site registrations:

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-network-connect/manage/site_management/registrations;tab=pending

and existing site registrations:

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-network-connect/manage/site_management/registrations;tab=other

URL for the site list:
- Note the namespace to use in the F5 XC UI is 'multi-cloud-openshift' and not 'default'.

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-app-connect/namespaces/multi-cloud-openshift/sites/site_list

URL for managing (deleting) sites:

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-network-connect/overview/sites/dashboard

URL for the site map:

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-app-connect/namespaces/multi-cloud-openshift/sites/site_map

URL for the HTTP Load Balancers

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-app-connect/namespaces/multi-cloud-openshift/manage/load_balancers/http_loadbalancers

URL for the Origin Poola

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-app-connect/namespaces/multi-cloud-openshift/manage/load_balancers/origin_pools 

URL for Health Checks 

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-app-connect/namespaces/multi-cloud-openshift/manage/load_balancers/health_checks 

URL for viewing and creating site tokens:

https://f5-asean.console.ves.volterra.io/web/workspaces/multi-cloud-network-connect/manage/site_management/site_tokens

URL for managing API credentials:

https://f5-asean.console.ves.volterra.io/web/workspaces/administration/personal-management/api_credentials

URL for domain name management:

https://f5-asean.console.ves.volterra.io/web/workspaces/dns-management/manage/dns_domain

URL to manage F5 XC monitors (useful to send traffic to the demo app):

https://f5-asean.console.ves.volterra.io/web/workspaces/observability/namespaces/multi-cloud-openshift/manage/synthetic-monitors/http-monitors 


If you see the following error in the ves-system, namespace, then more worker nodes need to be added, add one more node to each cluster where F5 is running:

```
ver-0   0/17   Pending
```

To add a node to all clusters, run the following:
```
for site in a b c 
do
   MS=`oc --context=login-$site get machineset -n openshift-machine-api --no-headers -l hive.openshift.io/machine-pool=worker | head -1 | awk '{print $1}'` 
   oc --context=login-$site -n openshift-machine-api scale machineset $MS --replicas=2
done
```

If you see the following error it means you need to authenticate 'vesctl' to F5 XC.  To do this fetch an API token from the F5 XC Console and configure 'vesctl', as described above. 

```
Error: Error constructing configapi.APIClient: Neither hw-key nor cert/key nor non-empty p12 bundle/password provided
```

Once the new sites (clusters) have been registered and confirmed you should see the following:

```
$ oc get po -n ves-system
NAME                          READY   STATUS    RESTARTS       AGE
etcd-0                        2/2     Running   0              84s
prometheus-644485989d-d7gll   5/5     Running   0              64s
ver-0                         16/16   Running   0              61s
volterra-ce-init-pcskh        1/1     Running   0              8m7s
volterra-ce-init-v85nw        1/1     Running   0              8m7s
volterra-ce-init-w6pc4        1/1     Running   0              8m7s
vp-manager-0                  1/1     Running   2 (112s ago)   7m34s
```

Be sure all pods are in the ready state!

Make sure there are no errors in:

```
oc logs vp-manager-0 -n ves-system
```


## Enable Huge Pages support

If you see this huge pages (HP) error, set up huge pages:

```
Insufficient hugepages-2Mi
```

Label one or more workers for Huge Page support 

```
for w in `oc get node -oname -l node-role.kubernetes.io/worker=`; do oc label $w node-role.kubernetes.io/worker-hp=; done
# Note, DO NOT set HP for the Submariner gateway nodes, as they will fail to boot
```

```
oc create -f yaml/hugepages/
```

Wait for all nodes to restart, re-configure and become ready:

```
oc get nodes -w
```

Verify HP has been set:

```
for w in `oc get node -oname -l node-role.kubernetes.io/worker=`; do echo -n "$w: "; oc get $w -o jsonpath="{.status.allocatable.hugepages-2Mi}"; echo; done
```

## Memory error

If you see the error: "maximum memory usage per Container"

```
oc describe StatefulSet ver
...
  Type     Reason            Age                   From                    Message
  ----     ------            ----                  ----                    -------
  Warning  FailedCreate      34m (x3 over 42m)     statefulset-controller  create Pod ver-0 in StatefulSet ver failed error: pods "ver-0" is forbidden: [maximum memory usage per Container is 6Gi, but limit is 8Gi, maximum memory usage per Pod is 12Gi, but limit is 19591593984, maximum cpu usage per Pod is 4, but limit is 9700m]
  Warning  FailedCreate      6m35s (x20 over 42m)  statefulset-controller  create Pod ver-0 in StatefulSet ver failed error: pods "ver-0" is forbidden: [maximum memory usage per Container is 6Gi, but limit is 8Gi, maximum cpu usage per Pod is 4, but limit is 9700m, maximum memory usage per Pod is 12Gi, but limit is 19591593984]
  Normal   SuccessfulCreate  9s                    statefulset-controller  create Pod ver-0 in StatefulSet ver successful
```

Delete the limits

```
oc delete limits ves-system-core-resource-limits -n 
```

## Vesctl CLI on Linux

SELinux needs to be disabled, otherwise vesctl core dumps on start.

```
setenforce 0
```

