# Set up F5 Volterra based HTTP Load Balancers

The below instructions were created from the following documents:

- Main OCP instructons: https://docs.cloud.f5.com/docs/integrations/integrating-cloud-mesh-with-ocp
- Aditional help: https://f5cloud.zendesk.com/hc/en-us/articles/4410470282263-How-to-create-Customer-Edge-CE-site-on-OpenShift-cluster 
- Get the CLI: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
- The orignal site tempalte: https://gitlab.com/volterra.io/volterra-ce/-/raw/master/k8s/ce_k8s.yml
- Generic Kubernetes site creation: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

Note: The above instriuctions mention configuring "Huge Pages" support.  In testing it was found that Huge Pages are needed!

If interested, see this article about Volterra architecture:
https://medium.com/volterra-io/managing-thousands-of-edge-kubernetes-clusters-with-gitops-82121f97dfeb

# Overall Process to set up F5 Volterra

One time tasks to set up the domains for each demo and the F5 UID

- hcd1.example.com
- hcd2.example.com
- hcd3.example.com

1 Install vecclt CLI 
  1 See: https://gitlab.com/volterra.io/vesctl/blob/main/README.md
1 Set up "$HOME/.vesconfig" by "Obtaining API Credentials from Volterra Console" using "API Certificate". Note, the cert has expiry date of 3 months! 
1 Set up domain delegation e.g. for xxx1.example.com, xxx2.example.com, xxx3.example.com 
1 Create the F5 UID

Check the available namespaces
```
./vesctl configuration list namespace
```

Can also view the namespaces here: https://f5-asean.console.ves.volterra.io/web/workspaces/administration/personal-management/namespaces

Set the namespace

```
export NS=multi-cloud-openshift
./vesctl configuration create token -i ../token/token-hcd.yaml 
./vesctl configuration get token hcd-token -o yaml -n $NS
./vesctl configuration delete token hcd-token -n $NS
```

## Create all F5 sites (ingress points) 

Once all clusters are up and their context (make contexts) properly set

1 Either run 'make contexts' ot log into all 3 clusters and rename the context (see below)
1 For all 3 clusters, bring up the initial sites
1 Wait for the site to register 
1 Confirm the pending registration in the F5 UI
1 Configure http load ballancers for all 3 sites 


```
oc login ...
oc config rename-context $(oc config current-context) login-a
oc login ...
oc config rename-context $(oc config current-context) login-b
oc login ...
oc config rename-context $(oc config current-context) login-c

oc config use-context coolstore-a
oc config use-context coolstore-b
oc config use-context coolstore-c
```

# Miscellanious Notes


## Follow these instructons

Fetch the CLI:

```
curl -LO "https://vesio.azureedge.net/releases/vesctl/$(curl -s https://downloads.volterra.io/releases/vesctl/latest.txt)/vesctl.darwin-amd64.gz"
```

---

Make sure no errors in 

```
oc logs vp-manager-0 -f
```

# Create a http LB

```
./vesctl configuration create token -i token-hcd.yaml
```

Add new uid into ce_k8s-coolstore-a.yaml @ "Token: "

```
oc create -f ce_k8s-coolstore-a.yaml

$ oc get po
NAME                     READY   STATUS    RESTARTS   AGE
volterra-ce-init-pcskh   1/1     Running   0          58s
volterra-ce-init-v85nw   1/1     Running   0          58s
volterra-ce-init-w6pc4   1/1     Running   0          58s
vp-manager-0             1/1     Running   0          25s
```

**WAIT** for all pods to be up and running

# A "Site registration" is created and shown in the UI which needs to be "accepted"

Accept the site registration

# **WAIT** for all pods to be up and running, e.g. etcd-0 and ver-0
 
```
$ oc get po -w
NAME                          READY   STATUS    RESTARTS       AGE
etcd-0                        2/2     Running   0              84s
prometheus-644485989d-d7gll   5/5     Running   0              64s
ver-0                         16/16   Running   0              61s
volterra-ce-init-pcskh        1/1     Running   0              8m7s
volterra-ce-init-v85nw        1/1     Running   0              8m7s
volterra-ce-init-w6pc4        1/1     Running   0              8m7s
vp-manager-0                  1/1     Running   2 (112s ago)   7m34s
```

Be sure all pods are ready!

How to create F5 configs

```
./vesctl configuration create healthcheck -i healthcheck-coolstore.yaml
./vesctl configuration create origin_pool -i  origin_pool-coolstore-a.yaml 
./vesctl configuration create http_loadbalancer -i lb-hcd-glb.yaml
```

```
# Fetch the CNAME from the Http LB
./vesctl configuration get http_loadbalancer hcd-glb -o yaml| grep host_name
```

# Clean up

```
./vesctl configuration delete  http_loadbalancer hcd-glb 
```

---
# Troubleshooting

If you see this HP error, set up huge pages:

Insufficient hugepages-2Mi

# Set up Huge Page support 

Label workers 

```
for w in `oc get node -oname -l node-role.kubernetes.io/worker=`; do oc label $w node-role.kubernetes.io/worker-hp=; done
# Note, DO NOT set HP for the Submainer gateway nodes, as they will fail to boot
```

# Enable Huge Pages support

```
oc create -f yaml/hugepages/
```

Wait for all nodes to re-configure...

```
oc get nodes -w
```

Verify HP has been set

```
for w in `oc get node -oname -l node-role.kubernetes.io/worker=`; do echo -n "$w: "; oc get $w -o jsonpath="{.status.allocatable.hugepages-2Mi}"; echo; done
```

---

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

---
DNS

Add domain from CLI:

```
./vesctl configuration create dns_domain -i  add-domain-example.yaml
vesctl configuration get dns_domain -n system hcd1.example.com   |  grep txt_record
txt_record: ves-io-60a9e949-01b9-4a1b-80e8-bc6202361053
```

```
$ dig hcd1.example.com ns +short
ns1.volterradns.io.
ns2.volterradns.io.
ns3.volterradns.io.
ns4.volterradns.io.
```

```
$ host -t ns hcd1.example.com 
hcd1.example.com name server ns1.volterradns.io.
hcd1.example.com name server ns2.volterradns.io.
hcd1.example.com name server ns3.volterradns.io.
hcd1.example.com name server ns4.volterradns.io.
```

