# Configure F5 Distributed Cloud (F5 XC) Global Load Balancer 

Reference documentation:

- Main OCP instructions: https://docs.cloud.f5.com/docs/integrations/integrating-cloud-mesh-with-ocp
- Additional help: https://f5cloud.zendesk.com/hc/en-us/articles/4410470282263-How-to-create-Customer-Edge-CE-site-on-OpenShift-cluster 
- Get the vesctl CLI: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
- The original site template: https://gitlab.com/volterra.io/volterra-ce/-/raw/master/k8s/ce_k8s.yml
- Generic Kubernetes site creation: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site
- Article about F5 XC Architecture: https://medium.com/volterra-io/managing-thousands-of-edge-kubernetes-clusters-with-gitops-82121f97dfeb

Note: The above instructions mention configuring "Huge Pages" support.  In testing it was found that Huge Pages are needed, otherwise the 'ver-0' pod stay 'Pending'!


## Overall Process to set up F5 XC 

### One time tasks to set up the domains for each demo and the F5 UID

1. Install vesctl CLI.  See: https://gitlab.com/volterra.io/vesctl/blob/main/README.md.
    1. To run on RHEL, be sure to turn off SELinux, otherwise vesctl will crash/core dump on startup.  Use 'sudo setenforce 0'. 
    1. Go to this [F5 XC page](https://f5-asean.console.ves.volterra.io/web/workspaces/administration/personal-management/api_credentials) to create an API Certificate. 
    1. See below example on how to configure the '$HOME/.vesconfig' file. 
1. Set up [domain delegation in F5 XC](https://docs.cloud.f5.com/docs/how-to/app-networking/domain-delegation) for the domains you want to use.
    1.  Note that some domains have already been set up for use, e.g.:
        1.  hcd1.ltsai.com
        1.  hcd2.ltsai.com
        1.  hcd3.ltsai.com
        1.  hcd1.bylo.de
        1.  hcd2.bylo.de
        1.  hcd3.bylo.de
1. Create an F5 UID and add it to the config file you intend to use (e.g. f5/hcd-coolstore-multi-cluster.yaml), which is used in the F5 configuration.

## Create all F5 XC sites (ingress points)

Once all clusters are up.  The high-level process to set up F5 XC is as follows: 

1. Log into the Hub cluster and run 'make contexts'. 
1. Copy one of the config files f5/hcd*yaml, e.g. cp f5/hcd-coolstore-multi-cloud.yaml f5/hcd-my-config-file.yaml' and edit the file.  Make changes to the configuration to match your application's ingress needs.  There are comments in the config file to help you. 
1. For all clusters, bring up the initial F5 'sites' (all pods in ves-system namespace) 
  1. Run the command 'scripts/configure-f5 f5/hcd-my-config-file.yaml'.
1. Wait for the site to register with F5 XC.
1. The generated pending 'site registration' is approved automatically.
1. Configure health checks, origin pools and http load balancers for all sites.

Example Configration for vesctl

Follow these instructions: https://gitlab.com/volterra.io/vesctl/blob/main/README.md 

You will need to log into the F5 XC UI, create & download an API Certificate (p12) file and configure the $HOME/.vesconfig file like this:

```
server-urls: https://f5-asean.console.ves.volterra.io/api
p12-bundle: /home/user/path-to/f5-asean.console.ves.volterra.io.api-creds.p12
```

Set the VES_P12_PASSWORD env variable with the password you set to encrypt your API Certificate, e.g.

```
export VES_P12_PASSWORD=password
```


# Miscellaneous Notes

Fetch the CLI:

```
curl -LO "https://vesio.azureedge.net/releases/vesctl/$(curl -s https://downloads.volterra.io/releases/vesctl/latest.txt)/vesctl.darwin-amd64.gz"
```

# Troubleshooting

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

