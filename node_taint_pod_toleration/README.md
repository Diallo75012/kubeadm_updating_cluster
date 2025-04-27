# Taints & Tolerations
source: (doc taints and tolerations)[https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/]
**NOTE:**
if `.spec.nodeName` is specified in a `pod` then it will bypass the scheduler and not `taint` will be checked. It will be put in the `node` specified even if that one `pod` had a `toleration` not matching that `node` `taint` but it the node `taint` has a `NoExecute` `effect` in the `taint`, th epod will be ejected.

## Taints
- Taints are applied to `nodes` to tell which `pod` label is accepted to be scheduled in the `node`
In this example, `node1` is `tainted` to not accept any `pod` sheduled having `label` key `special` with value `mangakissa`
and the effect `:` `NoSchedule` to 'Not Schedule'.
If this `taint` already exists it can be deleted by adding same line but with a minus at the end `-` like `NoSchedule-` 
```bash
kubectl taint nodes node1 special=mangakissa:NoSchedule
```

## Toleration
- Tolerations are applied to `pods` to tell to scheduler where the `pod` can be scheduled
In this example of the `PodSpec` part of `pod` definition, we have two different ways of doing it: one with key/value and another with only key

```yaml
# key/value
tolerations:
# node taint need to match those fields when `Equal` `operator:` is used
- key: "special" # node tiant need to match key
  operator: "Equal"
  value: "mangakissa" # node taint need to match value
  effect: "NoSchedule" # node taint need to match effect

# key only
tolerations:
# node taint need to match those fields when `Exists` `operator:` is used
- key: "special" # node taint need to match key
  operator: "Exists"
  effect: "NoSchedule" # node taint need to match effect
```

### rules for `operator` in `toleration` `pod.spec`:
- `operator:` default value is `Equal` then a `value:` field should be specified
- if `operator:` is `Exists` then no `value:` field should be specified, it will match on `key:` and `effect:`

### rules for empty field
- if `key:` is empty then `operator:` have to be `Exists` and it will match all key/values. AND, `effect:` still need to match at the same time
- if `effect:` is empty then it will match all `effect:` with `key: <your_key>``

### values taken by `effect`
- `NoExecute`:
  - `taint` not tolerated: pods are evicted from the node
  - `taint` tolerated:
    - `tolerationSeconds` indicated in `pod`: after that timelapse the `pod` will be evicted from `node`
    - `tolerationSeconds` not indicated in `pod`: No eviction, `pod` will remain forever in `node`
- `NoSchedule`: existing `pod` on `node` not evicted, only `pod` with matching `toleration` can be schedule in `node` otherwise not
- `PreferredNoSchedule`: it is a `soft NoSchedule`, so scheduler will try to not put `pod` on `node` tainted
  or `pod` spec without `toleration` indicated, but it is not guaranteed.

### rules for mutiple `toleration:` indicated in same pod
Here the scheduler will work fine but use those as filters, checking `nodes` `taints`, the `pod` `effects` and `operators`

## list of `kubernetes` automatic `taints`
- `node.kubernetes.io/not-ready`: Node is not ready. This corresponds to the `NodeCondition` `Ready="False"`.
- `node.kubernetes.io/unreachable`: Node is unreachable from the node controller. This corresponds to the `NodeCondition` `Ready="Unknown"`.
- `node.kubernetes.io/memory-pressure`: Node has memory pressure.
- `node.kubernetes.io/disk-pressure`: Node has disk pressure.
- `node.kubernetes.io/pid-pressure`: Node has PID pressure.
- `node.kubernetes.io/network-unavailable`: Node's network is unavailable.
- `node.kubernetes.io/unschedulable`: Node is unschedulable.
- `node.cloudprovider.kubernetes.io/uninitialized`: For cloud to have time to make setup. After a controller from the `cloud-controller-manager` initializes this `node`, the `kubelet` removes this `taint`.

```yaml
tolerations:
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 6000 # unless you set it like that it is automatically set to 300 (5mn) by the the controller
```

## example `node drain` of `taints` automatically applied to the `node`
When a `node` is `drained`, the `node controller` or `kubelet` adds `taints` with `NoExecute effect`. 
It also adds `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable`


scenarios:
- 1) We can here justify that scenario with a troubleshooting in staging environment, so temporaly delete replicaset and then re-acquire pods: 
create deployment nginx with 1 replica only and use labels
create a pod with a label selector same as the deployment one to show that it dies
create a pod a label selector different from the deployment to show that it stays alive
delete the deployment tearing it down
keep the pod and deploy again with 3 replicas and show that that pod will be acquired by the replicaset (so replicaset will be only deploying 2 new pods and acquiring the existing one)
show labels grouping using -L which will create a column int he output of `get pods` using the key of the label

- 2) Pod deletion priority setup using annotation
- 1: first will be deleted any pods in `pending` state or `unschedulable`
- 2: then,  will come any pods with the `annotation`: `controller.kubernetes.io/pod-deletion-cost`. The lower number one is delete first and so on.
So here we could do a scenario to have pods being annotated and see how the deployment replicas are scaled down meaning in which order
We could create an error first having the full replicaspulling an image that doesn't exist
then patch some replicas to fix those pods and get those running
and then have the scaling down showing in which order those pods would be deleted
then do the deployment again with healthy pods 
then annotate some of those pods with the `annotation`: `controller.kubernetes.io/pod-deletion-cost` and then scale down to see in which order those are scale down


- 3) Scenario in which we would use `nodeselector` to affect pods in specific nodes
```
selector:
  matchLabels:
    component: redis
  matchExpressions:
    - { key: tier, operator: In, values: [cache] }
    - { key: environment, operator: NotIn, values: [dev] }
```
this would need us to label nodes and then have selectors in deploymed pods
this also could be used with `selector` and use `matchExpression` in order to show IN/NOTIN/EXIST/DOESNOTEXIST 
little explanation of those:
```
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

```

```
selector:
  matchLabels:
    component: redis
  matchExpressions:
    - { key: tier, operator: In, values: [cache] }
    - { key: environment, operator: NotIn, values: [dev] }
```

- 4) Scenario in which we would show how labelling helps groups resources and have nice Cluster resources view by grouping those in representative custom columns
```
k get pod --all-namespaces --show-labels -o wide
```
```
k get pod --all-namespaces -Lcontroller-revision-hash -Lk8s-app -Lcomponent
```

- 5) Scenario in which we would use a `nodeSelector` and then a node `affinity` to show that we can set more specific rules using `affinity`
- `requiredDuringSchedulingIgnoredDuringExecution`: `required` so MUST be equal to those specifications.
- `preferredDuringSchedulingIgnoredDuringExecution`: `preferred` so NOT STRICT RULE but preferred rule.
here show emphasis in explaning the ORed and ANDed of matchExpressions
```
# ANDed
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
```
# ORed
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

- 6) Scenario in which we will use again Japanese locations to show how `node` `taint` and `effect` work with `pod` `toleration`
  - `NoExecute`: first create a deployment with 3 replicasets, then taint one node with effect `NoExecute` to `evict` the pod and show that it is recreated in another node, then taint another node with the same way to show that pods are again evited and will recreated somewhere else. then untaint one node and delete one of the deplyed pods which will be redeployed in the untainted node. Then do the same with the other tainted node by untainting it and deleting the one of the two pods which are on the same node and it will we rescheduled in another node.
    - now use yaml file only:
      ```yaml
      tolerations:
      - key: "special"
        operator: "Equal"
        value: "mangakissa"
        effect: "NoSchedule"
        tolerationSeconds: 30 # how long before being evicted
      ```

  - `NoSchedule`: use from here only `yaml` file
      ```yaml
      tolerations:
      - key: "special"
        operator: "Equal"
        value: "mangakissa"
        effect: "NoSchedule"
      ```
     Then taint the node with matching `taint` and `effect` and you should see that existing pods are not evicted
     then create a standalone pod with a nodeSelector or Affinity to that node, to show that it won't be schedule there as it doesn't have the toleration for that node taint.
     then add the toleration to the pod yaml file and show that now it can be scheduled there
     then get rid of the toleration of the pod keeping the affinity or nodeselector and taint the node with `preferredNoSchedule` the soft version and see that pod will be scheduled there (maybe need to try...)

  - `NoExecute`: create two pods with affinity of node selector just to maake sure those two are scheduled in the same node.
    both will have a toleration with effect `NoExecute` but one has the `tolerationSeconds` and the other not
    then taint the node where those two pods are located with same taint matching their toleration therefore effect `NoExecute`
    You will see that the pod not having the `tolerationSeconds` will stay in the node while the other one will be evicted after those `tolerarionSeconds`
