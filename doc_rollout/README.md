# Kubernetes RollBack ('rollout undo')
source: [rollout history and rollout undo](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment)
- check the history of different revisions. The biggest number is the lastest and the `1` is the oldest
```bash
 k rollout history  deployment nginx -n nginx
```
- You can have the a description recorded btu not using flag `--record` which is deprecated but using an `annotation`
eg.: patching a deployment and adding an annotation type `kubernetes.io/change-cause:<the cause of the change>`
```yaml
metadata:
  annotations:
    kubernetes.io/change-cause: "Shibuya is not accessible today, VIOLET ALERT!"
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: nginx-violet
          mountPath: /usr/share/nginx/html/
      volumes:
      - name: nginx-violet
        configMap:
          name: nginx-html
```
- rollback is done still using the keyword `rollout` but with `undo` and `--to-revision=<nbr of revision shown in history>`
```bash
- example output of some with the command used that use `--record` deprecated flag, some the `annotation` and some nothing:
k rollout history  deployment nginx -n nginx
Outputs:
deployment.apps/nginx 
REVISION  CHANGE-CAUSE
4         <none>   # example of nothing specified
5         <none>
6         <none>
7         <none>
8         <none>
10        kubectl patch deployment nginx --namespace=nginx --type=merge --   # example of `--record` flag used (deprecated)
11        kubectl patch deployment nginx --namespace=nginx --type=merge --
12        Shibuya is not accessible today, VIOLET ALERT!    # example of the `annotations: kubernetes.io/change-cause: "<cause to put here>" 
13        Shibuya is not accessible today, VIOLET ALERT
14        kubectl patch deployment nginx --namespace=nginx --type=merge --patch-file=nginx-deployment-patching.yaml --record=true
15        kubectl patch deployment nginx --namespace=nginx --type=merge --patch-file=nginx-deployment-patching.yaml --record=true
```
```bash
# now we perform the rolback
k rollout undo deployment/nginx -n nginx --to-revision=9
Outputs:
deployment.apps/nginx rolled back
```

Now at every use of the command `k rollout undo` or `k rollout restart` we will have a new `revision` numbered line in the history. 

rollout is just for: `kind:` `Deployments` or`ReplicaSets` or `StatefulSets`

**NOTE:**
When a `node` is down you lose all and `kubernetes` only can recreate pods in other nodes if they use `replicasets` under the how.
So only `kind:` `kind:` `Deployments` or`ReplicaSets` or `StatefulSets` are getting the change to have their pods redeployed in healthy nodes.
The standalone pods, are not recreated and lost, if using `hostPath` or
`local` `persistent volumes` it is lost as it leaves in the `node` so you better use `ebs`,
`nfs` or remote persistant volumes so that new pod recreated in other nodes will be able to reach those.
`DaemonSet`, `CongiMap`, `Secret`, `ServiceAccount`, `Service`: 
  all of those will survive! so for standalone `pods` better change `kind` from `kind: Pod` to `kind: Deployment`
  so that they will be rescheduled in another healthy `node`.

