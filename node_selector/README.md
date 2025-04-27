# Labels & Selectors
source: (Kubernetes Documentation)[https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/]

## Labels & Selectors Using `ReplicaSets` as example

(label names standards depending on DNS type name possibility or not)[https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-label-names]

**Important:**
- make sure that the `Selectors` do not match the labels of some resources implementing `ReplicaSets` for example.
  otherwise you risk to have that `pod` being `acquired` by the resource implementing `Replicasets`

We will provide examples of `kind: Deployment` or `kind: ReplicaSet` that will have a certain number of `replicas` count. And we will see what happen when you create a pods before that with a `selector` that have same label as the `replicaSet` implemented resource.
Answer is that:
  - if the `pod` is created after the `ReplicaSet`, the `pod` will be kiled instantly as the `ReplicaSet` have already reach maximum of `replicas` counts deployed in the cluster.
  - if the `pod` is created before the `ReplicaSet`, when the `ReplicaSet` will be deployed to the cluster, it will acquire those pods having the `Selector` matching its `labels`, therefore it will only add pods on top of what it has in `replicas` count OR will aquire pods until it fulfills its scaling `replicas` count and would kill all other pods having `selector` matching it `labels`
**So Be Very Carefull Here!**

### `ReplicaSets` restart policy
Source: (restart policy doc)[https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy]
- `Always`: default, always restarts container on terminaison
- `OnFailure`: restarts container on error
- `Never`: Never restarts container, dead/terminaison/error/other just bye bye!

### `ReplicaSets` `Selector` of `pod` `Labels` to acquire in yaml
- the yaml file has more field but this is extraction of what we are focusing on this example
```yaml
spec:
  selector:
    matchLabels:
      tier: junko
  # `template` part need also to therefore have a `label` and MUST match the `selector` `matchlabels` to not be rejected by the API Server
  template:
    metadata:
      labels:
        tier: junko
```

### Using REST API to delete `ReplicaSet`
There is different ways to interact with the custer and here we are not passing by the API Server but using REST API
to perform action on the Cluster. It is passing through the `Front Proxy`
```bash
kubectl proxy --port=8080
curl -X DELETE  'localhost:8080/apis/apps/v1/namespaces/default/replicasets/frontend' \
  # option `propagationPolicy have to be `Foreground` or `Background`, if using instead `orphan` it will delete only the replicaset and not affect pods.
  # which will be still there but not manage anymore by `ReplicaSet` so not recreated if they die(error) or terminate
  -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Foreground"}' \
  -H "Content-Type: application/json"
```
- Here `propagationPolicy` can be `orphan`, but why use this behavior of getting rid of the `replicaset` but keeping the `pods` in the Cluster as standalone `pods`?
  - for example, if we want to debug or test a new version in a specific pod and don't want to replicaset to restart the pods,
    we can't just scale down it to `0`. We can use this strategy to get rid of the `replicaset` temporaly and then recreate a new one that would `acquire` those pods back based on `labels` for example.
  - imperative command:
    - `kubectl delete replicaset <rs-name> --cascade=orphan`
    - `kubectl delete replicaset my-rs --grace-period=0 --cascade=orphan --force`

### 'acquire` rules
`Pods` -> `ReplicaSet` -> `Deployment`
- `Deployment` does manage the `ReplicaSet` and not the `Pod` so tell it: `Yo! Make sure that the pods are running with this container and replicas`
- `ReplicaSet` does manage the `Pod` and his boss the `Deployment` manages him OR `ReplicaSet` can be in cluster just to manage `Pod` without being part of `Deployment`
- `Pod` is managed by `ReplicaSet` or just running as a standalone `Pod`
- Therefore:
  - `Deployment` will adopt `ReplicaSet` if:
    - `ReplicaSet` has **no `ownerReferences`**
    - `ReplicaSet`’s `spec.selector` **matches** **`Deployment`'s selector**
    - `ReplicaSet`’s template **matches** **`Deployment`'s `Pod` template**
  - `ReplicaSet` can adopt a `Pod` if:
     - `Pod` **matches** the `ReplicaSet`’s **label selector**
     - `Pod` has **no `ownerReference`** (i.e., it’s "orphaned"): `kubectl get pod <pod_name> -o jsonpath='{.metadata.ownerReferences}'`
     - `Pod` `template spec` is an **exact match** with the **`ReplicaSet`'s template** (containers, volumes, etc.)


### When Scaling Down `ReplicaSets` How Pods Deletion Are Prioritized:
- 1: first will be deleted any pods in `pending` state or `unschedulable`
- 2: then,  will come any pods with the `annotation`: `controller.kubernetes.io/pod-deletion-cost`. The lower number one is delete first and so on.
- 3: then, `pods` on `nodes` with more `replicas` are delete first compared to pod on nodes having less replicas.
- 4: then comes, `pods` created more recently comes first if their creation time differs
- 5: randomly delete `pods` if all above matches

Note about the `annotation: controller.kubernetes.io/pod-deletion-cost`: between `-2147483648 and 2147483647` and it is `best-effort` so doesn't guarantees any deletion in the order (info about pod deleition cost annotation)[https://kubernetes.io/docs/reference/labels-annotations-taints/#pod-deletion-cost]

## `Labels` and `NodeSelectors` Using `Pods` as Example

### `pod` yaml example
taken from kubernetes documentation, here the pod will be selecting node with label `accelerator:nvidia-tesla-p100`
```yaml
spec:
  containers:
    - name: cuda-test
      image: "registry.k8s.io/cuda-vector-add:v0.1"
      resources:
        limits:
          nvidia.com/gpu: 1
  nodeSelector:
    accelerator: nvidia-tesla-p100
```

### `Set-Based` Requirement meaning filtering on the label keys and using keywords for values
- keywords for values:
  - `!`: means NOT and placed in front of key to excluse those keys
- keywords for values:
  - `in`: values are `EQUAL` to in the set of values supplied
  - `notin`: values are `NOT EQUAL` to in the set of values supplied
  - `exists`: a label that does exist (only check key not value)
  - `DoesNotExist`: a label that does not exist (only check key not value)
  - `,`: comma means `AND`

eg. of meanings :
```yaml
:
# key=`citynode`, values accepted=`tokyo` AND (because of comma: `,`) hokkaido
citynode in (tokyo, hokkaido)
# key=`nevereurope`, values=france AND emgland
nevereurope notin (france, england)
# key exclusive without value indicated. key=`shibuya`
shibuya
# key=NOT EQUAL to (because exclamation mark: `!`) shinjuku
!shinjuku
### more complexe requirements
# (key=`mangakissa`, with values=`ueno` AND `omotesando`), AND (key=`appdeploymentgroup`, values: NOT EQUAL to `production`)
mangakissa in (ueno, omotesando), appdeploymentgroup!=production
# checks if key `shomikitazawa` exist (not value)
exists: shimokitazawa
```

`Set-Based` requirements uses keywords while the other `Equality-Based` requirements are using `=`, `==` `!=`
We can use any of those two in our imperative commands:
```bash
kubectl get pods -l appdeploymentgroup!=production,magakissa=shibuya
kubectl get pods -l 'appdeploymentgroup in (staging),mangakissa in (shibuya)'
```

- in this `yaml` example from the `Kubernetes` documentation, satisfaction in when `ALL` `matchExpressions` **MUST** be satisfied
```yaml
selector:
  matchLabels:
    component: redis
  matchExpressions:
    - { key: tier, operator: In, values: [cache] }
    - { key: environment, operator: NotIn, values: [dev] }
```

## What is `ANDed` (`AND`) and What is `ORed` (`OR`)

### `matchExpressions`
- Here all conditions must be true (AND logic)
```yaml
matchExpressions:
  - key: env
    operator: In
    values: [prod, dev]
  - key: app
    operator: Exists
```
This matches only Pods that: have env=prod or env=dev `AND` have the label app (any value)

### `nodeSelector`
- Here `nodeSelector`: Only `AND`, no `OR`
```yaml
spec:
  nodeSelector:
    env: prod
    region: us-west
```
strictly: env == prod `AND` region == us-west, **No** support for `OR` here.


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
