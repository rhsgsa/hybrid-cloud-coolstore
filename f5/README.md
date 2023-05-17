# Configure F5 Distributed Cloud (F5XC) Global Load Balancer 

Reference documentation:

- Main OCP instructons: https://docs.cloud.f5.com/docs/integrations/integrating-cloud-mesh-with-ocp
- Aditional help: https://f5cloud.zendesk.com/hc/en-us/articles/4410470282263-How-to-create-Customer-Edge-CE-site-on-OpenShift-cluster 
- Get the CLI: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
- The orignal site template: https://gitlab.com/volterra.io/volterra-ce/-/raw/master/k8s/ce_k8s.yml
- Generic Kubernetes site creation: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

Note: The above instructions mention configuring "Huge Pages" support.  In testing it was found that Huge Pages are needed!

If interested, see this article about the Volterra architecture:
- https://medium.com/volterra-io/managing-thousands-of-edge-kubernetes-clusters-with-gitops-82121f97dfeb

# Overall Process to set up F5 XC (Volterra)

One time tasks to set up the domains for each demo and the F5 UID

1. Install vecclt CLI.  See: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
1. Set up "$HOME/.vesconfig" by "Obtaining API Credentials from Volterra Console" using "API Certificate". Note, the cert has expiry date of 3 months! 
1. Set up domain delegation e.g. for hcd1.example.com, hcd2.example.com, hcd3.example.com 
1. Create the F5 UID


## Create all F5 XC sites (ingress points) 

Once all clusters are up and their context (make contexts) properly set:

1. Run 'make contexts' 
1. For all 3 clusters, bring up the initial sites (all pods in ves-system namespace) 
1. Wait for the site to register 
1. Confirm the pending registration in the F5 UI
1. Configure http load ballancers for all 3 sites 


# Miscellanious Notes

Fetch the CLI:

```
curl -LO "https://vesio.azureedge.net/releases/vesctl/$(curl -s https://downloads.volterra.io/releases/vesctl/latest.txt)/vesctl.darwin-amd64.gz"
```

# Troubleshooting

Once the new sites (clusters) have been regsistered and confirmed you should see the following:

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


# Enable Huge Pages support

If you see this huge pages (HP) error, set up huge pages:

```
Insufficient hugepages-2Mi
```

Label one or more workers for Huge Page support 

```
for w in `oc get node -oname -l node-role.kubernetes.io/worker=`; do oc label $w node-role.kubernetes.io/worker-hp=; done
# Note, DO NOT set HP for the Submainer gateway nodes, as they will fail to boot
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


