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
___________
(From documentation for: `ownerReferences`)[https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/]
# Pod being acquired
cat pod.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-standalone
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx
```

`kubectl get pod <standalone_pod_name> -o jsonpath='{.metadata.ownerReferences}'`

cat replicaset.yaml
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
```

`kubectl get pod <standalone_pod_name> -o jsonpath='{.metadata.ownerReferences}'`

# Replicset being acquired

cat replicaset.yaml
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-orphan-rs
  # make sure to not forget to add here the label matching the one of the deployment otherwise this replicaset won't be acquired by the deployment
  labels: 
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
```

`kubectl get rs <replicaset_name> -o jsonpath='{.metadata.ownerReferences}'`


cat deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-adopter
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
```
`kubectl get rs <replicaset_name> -o jsonpath='{.metadata.ownerReferences}'`
