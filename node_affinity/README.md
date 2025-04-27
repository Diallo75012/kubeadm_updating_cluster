# Node Affinity and Anti-Affinity

- here we can use `nodeSelector` which only select nodes with specific labels
- vs Node `affinity`/ `anti-affinity` adds some more option and control over the node selection:
  - `soft` and `preferred` keyword can be used to tell `scheduler` to schedule `pod` event no `nodes` are matching
  - or create rules based on other `pods` `labels`

From kubernetes Documentation. (source)[https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/]:
- `Node affinity` functions like the `nodeSelector` field but is more expressive and allows you to specify soft rules.
- `Inter-pod` `affinity/anti-affinity` allows you to constrain `Pods` against `labels` on other `Pods`.

## Node Affinity
- two keywords, Like `nodeSelector` but with more detailed specification:
  - `requiredDuringSchedulingIgnoredDuringExecution`: `required` so MUST be equal to those specifications.
  - `preferredDuringSchedulingIgnoredDuringExecution`: `preferred` so NOT STRICT RULE but preferred rule.

Eg. from kubernetes documentation (just spec of pod part targeting our subject):
(`operator` can be any of those values: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt` or `Lt`)
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution: # MUST: for the rules coming after that
        nodeSelectorTerms:
        - matchExpressions: # if many `matchExpressions` it is `AND` so all have to match for `pod` to be scheduled
          - key: topology.kubernetes.io/zone
            # can be: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt` or `Lt`
            operator: In
            values: # OR `antarctica-east1` OR `antarctica-west1`
            - antarctica-east1
            - antarctica-west1
      preferredDuringSchedulingIgnoredDuringExecution: # PREFERRED but not obliged to: for the rules coming after that
      - weight: 1 # can be from 1 to 100. If many different `preferences` `weight` is calculated. `Nodes` satisfying highest score are prioritized
        preference:
          matchExpressions:
          - key: another-node-label-key
            # can be: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt` or `Lt`
            operator: In
            values:
            - another-node-label-value
```

## ** Notes from documentation **
Note:
- specify both `nodeSelector` and `nodeAffinity`: both must be satisfied for the Pod to be scheduled onto a node.
- specify multiple terms in `nodeSelectorTerms` with `nodeAffinity` types:  `Pod` can be scheduled to node if one specified terms can be satisfied (`OR`).
- specify multiple expressions in a single `matchExpressions` associated with a term in `nodeSelectorTerms`: `Pod` can be scheduled on node only if all expressions satisfied (`AND`)

## Node Anti-Affinity
Is done using keyword in `operator`:
- `NotIn`
- `DoesNotExist`


### `nodeAffinity` (same for: `podAffinity`)
- `AND`: `requiredDuringSchedulingIgnoredDuringExecution` (hard constraints) only supports `AND` across matchExpressions.
  So here inside one `matchExpressions` if there more than one option it is `AND` so all of those have to be true
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: env
          operator: In
          values: [prod]
        - key: region
          operator: In
          values: [us-west]
```
That means: (env == prod) `AND` (region == us-west)

- `OR`: `requiredDuringSchedulingIgnoredDuringExecution` also support `OR` but this time across several `match#xpressions` each `matchExpressions` being sets of `ORs`

You can provide multiple `nodeSelectorTerms` `matchExpressions`, and those terms are `ORed`.
Here match nodes that are either: env=prod `OR` region=us-west
```yaml
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: env
          operator: In
          values: [prod]
    - matchExpressions:
        - key: region
          operator: In
          values: [us-west]
```
(env == prod) `OR` (region == us-west): inside each individual `matchExpressions` terms are `ANDed`, the `nodeSelectorTerms` several `matchExpressions` between themselves are `ORed`

## Label Usefulness To Have View in Cluster With Different Parts Grouped in Custom Columns

- We get the cluster pods and show the labels to see what is present and be able to create columns like pivoting the output
```bash
k get pod --all-namespaces --show-labels -o wide
NAMESPACE     NAME                                                 READY   STATUS    RESTARTS        AGE     IP                NODE                         NOMINATED NODE   READINESS GATES   LABELS
kube-system   calico-kube-controllers-85578c44bf-xqlmz             1/1     Running   4 (133m ago)    4d15h   172.16.247.185    controller.creditizens.net   <none>           <none>            k8s-app=calico-kube-contr
ollers,pod-template-hash=85578c44bf
kube-system   calico-node-8v4pl                                    1/1     Running   19 (133m ago)   623d    192.168.186.146   controller.creditizens.net   <none>           <none>            controller-revision-hash=
754b4dfc9f,k8s-app=calico-node,pod-template-generation=1
kube-system   calico-node-wh76j                                    1/1     Running   6 (133m ago)    623d    192.168.186.147   node1.creditizens.net        <none>           <none>            controller-revision-hash=
754b4dfc9f,k8s-app=calico-node,pod-template-generation=1
kube-system   calico-node-zk8zl                                    1/1     Running   7 (133m ago)    623d    192.168.186.148   node2.creditizens.net        <none>           <none>            controller-revision-hash=
754b4dfc9f,k8s-app=calico-node,pod-template-generation=1
kube-system   coredns-5d78c9869d-kpbtn                             1/1     Running   5 (133m ago)    5d17h   172.16.247.183    controller.creditizens.net   <none>           <none>            k8s-app=kube-dns,pod-temp
late-hash=5d78c9869d
kube-system   coredns-5d78c9869d-l47pn                             1/1     Running   4 (133m ago)    4d15h   172.16.247.184    controller.creditizens.net   <none>           <none>            k8s-app=kube-dns,pod-temp
late-hash=5d78c9869d
kube-system   etcd-controller.creditizens.net                      1/1     Running   5 (133m ago)    5d18h   192.168.186.146   controller.creditizens.net   <none>           <none>            component=etcd,tier=contr
ol-plane
kube-system   kube-apiserver-controller.creditizens.net            1/1     Running   6 (133m ago)    5d18h   192.168.186.146   controller.creditizens.net   <none>           <none>            component=kube-apiserver,
tier=control-plane
kube-system   kube-controller-manager-controller.creditizens.net   1/1     Running   14 (133m ago)   5d18h   192.168.186.146   controller.creditizens.net   <none>           <none>            component=kube-controller
-manager,tier=control-plane
kube-system   kube-proxy-88h87                                     1/1     Running   4 (133m ago)    5d17h   192.168.186.147   node1.creditizens.net        <none>           <none>            controller-revision-hash=
747c75b954,k8s-app=kube-proxy,pod-template-generation=2
kube-system   kube-proxy-bs58j                                     1/1     Running   5 (133m ago)    5d17h   192.168.186.148   node2.creditizens.net        <none>           <none>            controller-revision-hash=
747c75b954,k8s-app=kube-proxy,pod-template-generation=2
kube-system   kube-proxy-mwnmk                                     1/1     Running   5 (133m ago)    5d17h   192.168.186.146   controller.creditizens.net   <none>           <none>            controller-revision-hash=
747c75b954,k8s-app=kube-proxy,pod-template-generation=2
kube-system   kube-scheduler-controller.creditizens.net            1/1     Running   14 (133m ago)   5d18h   192.168.186.146   controller.creditizens.net   <none>           <none>            component=kube-scheduler,
tier=control-plane
```

- We are going to make groups of `label` `keys` to have columns and group of resources
 
```bash
k get pod --all-namespaces -Lcontroller-revision-hash -Lk8s-app -Lcomponent 
NAMESPACE     NAME                                                 READY   STATUS    RESTARTS         AGE     CONTROLLER-REVISION-HASH   K8S-APP                   COMPONENT
kube-system   calico-kube-controllers-85578c44bf-xqlmz             1/1     Running   4 (3h21m ago)    4d16h                              calico-kube-controllers   
kube-system   calico-node-8v4pl                                    1/1     Running   19 (3h21m ago)   623d    754b4dfc9f                 calico-node               
kube-system   calico-node-wh76j                                    1/1     Running   6 (3h21m ago)    623d    754b4dfc9f                 calico-node               
kube-system   calico-node-zk8zl                                    1/1     Running   7 (3h21m ago)    623d    754b4dfc9f                 calico-node               
kube-system   coredns-5d78c9869d-kpbtn                             1/1     Running   5 (3h21m ago)    5d18h                              kube-dns                  
kube-system   coredns-5d78c9869d-l47pn                             1/1     Running   4 (3h21m ago)    4d16h                              kube-dns                  
kube-system   etcd-controller.creditizens.net                      1/1     Running   5 (3h21m ago)    5d19h                                                        etcd
kube-system   kube-apiserver-controller.creditizens.net            1/1     Running   6 (3h21m ago)    5d19h                                                        kube-apiserver
kube-system   kube-controller-manager-controller.creditizens.net   1/1     Running   14 (3h21m ago)   5d19h                                                        kube-controller-manager
kube-system   kube-proxy-88h87                                     1/1     Running   4 (3h21m ago)    5d19h   747c75b954                 kube-proxy                
kube-system   kube-proxy-bs58j                                     1/1     Running   5 (3h21m ago)    5d19h   747c75b954                 kube-proxy                
kube-system   kube-proxy-mwnmk                                     1/1     Running   5 (3h21m ago)    5d19h   747c75b954                 kube-proxy                
kube-system   kube-scheduler-controller.creditizens.net            1/1     Running   14 (3h21m ago)   5d19h                                                        kube-scheduler 
```

## `-l` to label pods or get pods based on labels, `-L` to create colum based on those labels keys

- from `Kubernetes` documentation
```bash
kubectl label pods -l app=nginx tier=fe

kubectl get pods -l app=nginx -L tier
Output:
NAME                        READY     STATUS    RESTARTS   AGE       TIER
my-nginx-2035384211-j5fhi   1/1       Running   0          23m       fe
my-nginx-2035384211-u2c7e   1/1       Running   0          23m       fe
my-nginx-2035384211-u3t6x   1/1       Running   0          23m       fe
```
