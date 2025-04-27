# storage

## persistant volumes (pvs)
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5gi
  volumemode: filesystem
  accessmodes:
    - readwriteonce
  persistentvolumereclaimpolicy: recycle
  storageclassname: slow
  mountoptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /tmp
    server: 172.17.0.2
```


like when a pod is created it request cpu and memory from the node,
here the `pvs` are the resources configured by th ecluster admin and `pvcs` (persistant volume claims) are like the pods requestiong for resources to be mounted.
different access depending on what it is wanted to be done, but not only,
also depends on the resource that is used for storage,
like some accept multiple entries while others have some different specifics:
**important those are not guaranteed as no constraint is put by kubernetes on those volumes**
- readwriteonce (rwo): `single node` mount, can be `red and written` by all pods living on that node.
- readonlymany (rox): this volume can be mounted as `read only` by `many modes`
- readwritemany (rwx): this volume can be mounted as `read and write` by `many modes`
- readwriteoncepod (rwop): this volume ensures that accros the whole cluster `only one pod` can `read and write` on the volume
source: (check doc to see table of volumes and what access mode they support or not)[https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes]

eg: `hostpath` is supporting only `readwriteonce`
and this is what we are probably going to use as we are running `kubeadm` locally
and not in the cloud (no `ebs` volumes for eg.) 

### storage class of pvs
`pvs` with annotation (might become deprecated) `volume.beta.kubernetes.io/storage-class`
or `storageclassname` (more actual way of doing it) would only be mounted by claims matching those
otherwise `pvs` without it would be bound to `pvcs` that do not specify storage class.

### reclaim policy
- retain -- manual reclamation
- recycle -- basic scrub (rm -rf /thevolume/*) and this only for `nfs` and `hostpath` types of volumes
- delete -- delete the volume

### affinity
can be set only when using `local`(which can only be a static pv and not dynamic one) `pvs`.

### example `yaml` file showing those previous concepts with field defined
source: (pvs type: local)[https://kubernetes.io/docs/concepts/storage/volumes/#local]
source: (storageclass creation)[https://kubernetes.io/docs/concepts/storage/storage-classes/#local]

so when using `local` types of volumes we **must** set node affinity!
here we do use example from documentation using `local` volumes to set `volumebindingmode` set to `waitforfirstconsumer` in the first `yaml` part.
other than that we could use are `hostpath` and `emptydir`. those could also be used for ssd/usb/filepath and depends on underlying system access to those.

```yaml
---
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner # indicates that this storageclass does not support automatic provisioning
volumebindingmode: waitforfirstconsumer

---
apiversion: v1
kind: persistentvolume
metadata:
  name: example-pv
# probably goes here
spec:
# here we set the capacity of this volume made available in the cluster to pods (in nodes following the defined affinity here)
  capacity:
    storage: 100gi
# `filestystem` if using file system otherwise use `block` as well for hard drives probably
  volumemode: filesystem
# the access mode rwo
  accessmodes:
  - readwriteonce
# the reclaim policy type set to `delete`
  persistentvolumereclaimpolicy: delete
# the `storageclassname` defined in the above `yaml`
  storageclassname: local-storage
# using here `local` which makes us then obliged to use node affinity
  local:
    path: /mnt/disks/ssd1
# here creating the node affinity constraint
  nodeaffinity:
    required:
      nodeselectorterms:
      - matchexpressions:
        - key: kubernetes.io/hostname
          operator: in
          values:
          - example-node
```

### little schema to understand
-> storageclass
  -> pv uses that storage class and defines volume size, access mode, reclaim policy, node affinity (if local type of volume)
    -> pods request the pv with the right storage class

**note:** delaying volume binding ensures that the persistentvolumeclaim binding decision will also be evaluated with any other node constraints the pod may have,
such as node resource requirements, node selectors, pod affinity, and pod anti-affinity.

### in the cloud
in the cloud it is different than locally running a kubernetes cluster as for the `csi` (container storage interface) different drivers would be used
so need to check on the documentation and also what is possible to do and not.
it works like that:
- `csi` driver is deployed in the kubernetes cluster
- then from that moment the cloud volumes would be available to be mounted and used. after depends on which ones are available
- different cloud providers have different settings in how many volumes max could be attached to a single node.
- need also to check on that. eg: x36 `ebs` volumes for `aws` on each node and there is an env var that can be modified to have control on that...check docs!.

### pvs phases
those are the different states that pvs can have:
- `available`: a free resource that is not yet bound to a claim
- `bound`: the volume is bound to a claim
- `released`: the claim has been deleted, but the associated storage resource is not yet reclaimed by the cluster
- `failed`: the volume has failed its (automated) reclamation



## persistant volume cliam pvcs
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: myclaim
spec:
  accessmodes:
    - readwriteonce
  volumemode: filesystem
  resources:
    requests:
      storage: 8gi
  storageclassname: slow
  selector:
      release: "stable"
    matchexpressions:
      - {key: environment, operator: in, values: [dev]}
```

### access modes and volumes types
same as `pvs` ones

### resources
here is the difference as this is a `claim` the pod would request for a certain amount of resources (like a pod would do to request cpu and memory).

### selectors
to match a set of specific volumes, volumes can be labelled and the `pvc` would use a selector like we do with pods.
it is anded:
- matchlabels - the volume must have a label with this value
- matchexpressions with operators: in, notin, exists, and doesnotexist

### class 'storageclass'
a `pvc` can actually specify a storage class by name using: `storageclassname`
if `storageclassname: ""`:
- it will be set for `pv` taht do not have any storage class name
  - if `defaultstorageclass` have been enabled in the kubernetes cluster.
    done by adding annotation: `storageclass.kubernetes.io/is-default-class:true` (will be deprecated, better to use `storageclassname`):
    - the `storageclassname: ""` request would be bounded to the default `storageclass` set by the kubernetes admin
  - if `defaultstorageclass` is not enabled: the `pvc` would be bound to the latest `pv` created. order is from the newest to the oldest if many.
    and those `pvs` need to also have `storageclassname: ""`.

some other rules:
- can create `pvc` without `storageclassname` only when the `defaultstorageclass` is not enabled.
- if no `storageclassname` defined when creating a `pvc` and then you enable `defaultstorageclass`, kubernetes would set `storageclassname: ""` to those `pvcs`
- if `storageclassname: ""` defined in `pvc` and then you enable `defaultstorageclass`, kubernetes won't update those `pvcs` as those are fine with the right `:""`

## namespaced or not?
- `pvs` are not namespaced
- `storageclasses` are not namespaces
- `pvcs` are yes namespaces
```bash
# k api-resources | grep "storageclasses"
storageclasses                    sc           storage.k8s.io/v1                      false        storageclass

# k api-resources | grep "pv"
persistentvolumeclaims            pvc          v1                                     true         persistentvolumeclaim
persistentvolumes                 pv           v1                                     false        persistentvolume
```

## claim as volume
source: (claims as volume)[https://kubernetes.io/docs/concepts/storage/persistent-volumes/#claims-as-volumes]
```yaml
apiversion: v1
kind: pod
metadata:
  name: mypod
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumemounts:
      - mountpath: "/var/www/html"
        name: mypd
  volumes:
    - name: mypd
      persistentvolumeclaim:
        claimname: myclaim
```

## raw block as volume
**note:** here instead of using `mountpath` on the pod `volume` we use `devicepath`
- `pv`
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: block-pv
spec:
  capacity:
    storage: 10gi
  accessmodes:
    - readwriteonce
  volumemode: block
  persistentvolumereclaimpolicy: retain
  fc:
    targetwwns: ["50060e801049cfd1"]
    lun: 0
    readonly: false

```
- `pvc`
```yaml apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: block-pvc
spec:
  accessmodes:
    - readwriteonce
  volumemode: block
  resources:
    requests:
      storage: 10gi
```
- `pod`
```yaml
apiversion: v1
kind: pod
metadata:
  name: pod-with-block-volume
spec:
  containers:
    - name: fc-container
      image: fedora:26
      command: ["/bin/sh", "-c"]
      args: [ "tail -f /dev/null" ]
      volumedevices:
        - name: data
# here we use `devicepath` instead of `mountpath`
          devicepath: /dev/xvda
  volumes:
    - name: data
      persistentvolumeclaim:
        claimname: block-pvc
```

## enabling `--feature-gates` to make cross-namespace volumes possible [`alpha`]
source: (cross namespace volumes)[https://kubernetes.io/docs/concepts/storage/persistent-volumes/#cross-namespace-data-sources]
kubernetes supports cross namespace volume data sources.
to use cross namespace volume data sources, 
you must enable the anyvolumedatasource and crossnamespacevolumedatasource feature gates for the kube-apiserver and kube-controller-manager. 
also, you must enable the crossnamespacevolumedatasource feature gate for the csi-provisioner.

enabling the crossnamespacevolumedatasource feature gate allows you to specify a namespace in the datasourceref field.


## strictly binding a pvc with a pv
**good if `pv` set `persistentvolumereclaimpolicy: retain`** 
source: (doc)[https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims]

- this will not strictly bind it:
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: foo-pvc
  namespace: foo
spec:
  storageclassname: "" # empty string must be explicitly set otherwise default storageclass will be set
  volumename: foo-pv
  ...
```
- this would strictly bind it by reserving that `pv` to that `pvc` using `claimref`:
therefore, here it has to be set also on the `pv` side the `claimref` referencing the corresponding `pvc`
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: foo-pv
spec:
  storageclassname: ""
# so here we use `clainref` to bind the `pv` to a claim
  claimref:
    name: foo-pvc
    namespace: foo
  ...
```
- recap comnditions for this to work:
`pvc` -> referencing the `pv` using `volumename`
`pv` -> referencing `pvc` using `claimref`

## recap (chatgpt)
### dynamic provisioning.
here kubernetes creates the `pv` **automatically**

**define:**
- a storageclass
- a pvc (that refers to that storageclass)
- and a pod that uses the pvc
- then kubernetes automatically creates the persistentvolume (pv)
- no need to pre-create a pv.


**why create pvs manually (static provisioning)?**
only create a pv manually when:
- static provisioning: have pre-existing storage (e.g., a mounted nfs share, disk partition, etc.) and want to bind it manually.
- want to control which pod gets which exact volume (e.g., binding a specific disk to a specific application).
- for air-gapped clusters or restricted environments where can't use dynamic storage backends.
- for on-premise storage where the admin provisions and maintains volumes manually.


**so two options:**
|option|what you define|who creates the pv|use case |
+-------+-----------------------+-----------------------+---------+
|dynamic provisioning|storageclass + pvc|kubernetes (automatically)|most common, easy, scalable|
+-----------------------+-----------------------+-------------------------------+---------------------------+
|static provisioning|pv + pvc|you (admin)|pre-provisioned disks, special use cases|
+-----------------------+---------------+---------------+----------------------------------------+

**can a pod bind to a specific pv?**
indirectly, yes — by:
- creating a pvc with:
  - the same:
    - storage size
    - accessmodes
  - and optionally matching the volumename or selector labels used by the pv

then the pvc will bind to that specific pv.

# when using `waitforfirstconsumer` in `storageclass`, you need to:
**important:**
let's say we are in the example of some `scheduling` rules for pods that need to be in certain zones or nodes in the world.
now the default behavior is `immediate` binding of the `pvc` to available volumes `pvs`. but this would by-pass the `scheduling` requirements.
therefore, an issue as you won't get your workload following the rule set for the `scheduler` in the `pod`. 
this is when we use `waitforfirstconsumer` for the `scheduler` to be taken into consideration by delaying the volume binding.
now it is given the time to understand the zones and nodes, the resouces limits (taint/toleration, affinity and more ...) in each for each pods and the full environemnt for a good scheduling of the volumes.
so here to resume we are not by-passing topology rules and scheduler contraints.

- `storageclass`: use of `waitforfirstconsumer` with `allowedtopologies`
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: standard
provisioner:  example.com/example
parameters:
  type: pd-standard
# can be `delete` to delete `pv` automatically created when `pvc` is deleted, or `retain` which is the default one keeping the volume created intact 
reclaimpolicy: delete
volumebindingmode: waitforfirstconsumer
allowedtopologies:
- matchlabelexpressions:
  - key: topology.kubernetes.io/zone
    values:
    - us-central-1a
    - us-central-1b
```
**notes about `retainpolicy`**: there is another `retainpolicy` also that can be set when setting `static` provisioning meaning that you are the one who
create the `pv`, the `pv` itself have a `persistentvolumereclaimpolicy` which takes precedence on the one set in the `storageclass` so no need to set one in the `storageclass` when creating a `static` volume. also it can be patched so changed. in the case of `dynamic` so creation by `storageclass` matching `pv` it will be taking the `storageclass` defined `reclaimpolicy`

- pod: not using `nodename` but `hostname` in selector when not using affinity
here we can see the way to use `nodeselector` as well
```yaml
spec:
  nodeselector:
    kubernetes.io/hostname: kube-01
```

# some extra to know
- `storageclass`(storageclass.yaml) is not indicating the `capacity`, but the `pvc`(pvc.yaml) would indicate `capacity` (`resources` -> `request` -> `storage`)
  and then the pod would reference that `pvc`.
  this is how the `pod` would get request resources satisfied and volume mounted ('persistentvolumeclaim' -> `claimname`). 
  `pv` would be created automatically (`dynamic`) by kubernetes.
- you need to install `csi` drivers if you want to extend storage to external ones (like they do in the cloud,
  see next the example with local `s3` like volume using `minio` which can listen to a directory path...)



# example `s3` like volume using `minio`
what is interesting with `minio` is that it can listen to a folder path if it is used for it's bucket path
so here the solution would  be to install a `csi` criver for the `s3` like volume.
and then have a local `minio` or `external` to the cluster listening on a node folder path or internal to the cluster sharing volume with the host node and being
used as `sidecar` container.
- **deploy the `csi` driver**: follow installation (instructions)[https://github.com/ctrox/csi-s3] of this `csi-s3` available on `github`
- **create storageclass**: this `storageclass` would be using it:
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: s3-storage
provisioner: s3.csi.k8s.io
parameters:
  bucket: my-bucket
  region: us-east-1
  mounter: rclone
  options: --s3-endpoint=https://s3.amazonaws.com
```
- **create `pvc`**: this `pvc` would reference the `storageclass`
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: s3-pvc
spec:
  accessmodes:
    - readwritemany
  resources:
    requests:
      storage: 5gi
  storageclassname: s3-storage
```
- and after just mount the volume to your `pod`.
- but actually this is where it is interesting as you don't even need to do that if is an `object store` like `s3` or `minio`.
  all you need here is to use the trick of shared volumes and use local `minio` path or `s3 sdk` or `sidecar` using `mc` (minio client)
minimal eg:. might need another `sidecar` for `sync data` with `minio` server.
```yaml
apiversion: v1
kind: pod
metadata:
  name: app-with-minio-sidecar
spec:
  containers:
    - name: my-app
      image: my-app-image
      volumemounts:
        - name: shared-data
          mountpath: /app/data
    - name: minio-sidecar
      image: minio/mc
      command: ["/bin/sh", "-c"]
      args:
        - |
          mc alias set myminio http://minio.default.svc.cluster.local:9000 minio minio123
          mc cp --recursive myminio/my-bucket /shared-data
          tail -f /dev/null
      volumemounts:
        - name: shared-data
          mountpath: /shared-data
  volumes:
    - name: shared-data
      emptydir: {}
```

- summary by `chatgpt`:
can i use it locally in kubeadm with minio? yes! you can:
- deploy minio as a pod.
- use an s3 csi driver that works with any s3-compatible storage (like minio).
- or use a sidecar container that downloads/upload files to minio.



# full example using locally `allowedtopologies` 

## static way:

- label nodes
```bash
kubectl label node node1 topology.kubernetes.io/zone=us-central-1a
kubectl label node node2 topology.kubernetes.io/zone=us-central-1b
```
- create `storageclass`:
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: standard-local
provisioner: kubernetes.io/no-provisioner  # no dynamic provisioning
volumebindingmode: waitforfirstconsumer    # bind pv only when pod is scheduled
allowedtopologies:
  - matchlabelexpressions:
      - key: topology.kubernetes.io/zone
        values:
          - us-central-1a
          - us-central-1b
```
- create a `pv` (manually not automatic which gives more control to admin, called `static` way):
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: local-pv-1
spec:
  capacity:
    storage: 2gi
  volumemode: filesystem
  accessmodes:
    - readwriteonce
  persistentvolumereclaimpolicy: retain
  storageclassname: standard-local
  local:
    path: /mnt/disks/ssd1  # you can `mkdir -p` this on the host manually
  nodeaffinity:
    required:
      nodeselectorterms:
        - matchexpressions:
            - key: topology.kubernetes.io/zone
              operator: in
              values:
                - us-central-1a
```
- create a `pvc`:
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: my-local-claim
spec:
  accessmodes:
    - readwriteonce
  resources:
    requests:
      storage: 2gi
  storageclassname: standard-local
```
- create a `pod`:
```yaml
apiversion: v1
kind: pod
metadata:
  name: local-storage-pod
spec:
  containers:
    - name: app
      image: nginx
      volumemounts:
        - mountpath: /usr/share/nginx/html
          name: data
  volumes:
    - name: data
      persistentvolumeclaim:
        claimname: my-local-claim
```

## dynamic way

- install `csi` driver for local provisioner from github (`rancher`)[https://github.com/rancher/local-path-provisioner]
it registers a storageclass named local-path which can be used for dynamic provisioning
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```
- change the `storageclass` with the `csi` driver deployed to the cluster
```
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: dynamic-local
provisioner: rancher.io/local-path  # or any csi driver available in your cluster
volumebindingmode: waitforfirstconsumer
```
- get rid of the previously created `pv` and use the `pvc` and `pod` (can change name if wanted to):
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: my-claim
spec:
  accessmodes:
    - readwriteonce
  resources:
    requests:
      storage: 1gi
  storageclassname: dynamic-local
```
```yaml
apiversion: v1
kind: pod
metadata:
  name: pod-using-dynamic
spec:
  containers:
    - name: app
      image: nginx
      volumemounts:
        - mountpath: /usr/share/nginx/html
          name: web-storage
  volumes:
    - name: web-storage
      persistentvolumeclaim:
        claimname: my-claim
```

# storage scenarios
- 1: create volumes `static way` with `storageclassname: ""`
     show also `claimref` for strictly binded `pv` to `pvc`
explain:
-> storageclass
  -> pv uses that storage class and defines volume size, access mode, reclaim policy, node affinity (if local type of volume)
    -> pods request the pv with the right storage class


- 2: create default `storageclasss` in cluster and show behavior of `storageclassname: ""`
explain:
a `pvc` can actually specify a storage class by name using: `storageclassname`
if `storageclassname: ""`:
- it will be set for `pv` that do not have any storage class name
  - if `defaultstorageclass` have been enabled in the kubernetes cluster.
    done by adding annotation: `storageclass.kubernetes.io/is-default-class:true` (will be deprecated, better to use `storageclassname`):
    - the `storageclassname: ""` request would be bounded to the default `storageclass` set by the kubernetes admin
  - if `defaultstorageclass` is not enabled: the `pvc` would be bound to the latest `pv` created. order is from the newest to the oldest if many.
    and those `pvs` need to also have `storageclassname: ""`.

`waitforfirstconsumer` and `affinity` to show how the pods are not respecting affinity when it is not set and how it by-passes the `scheduler`
can create `pvc` without `storageclassname` only when the `defaultstorageclass` is not enabled.
if no `storageclassname` defined when creating a `pvc` and then you enable `defaultstorageclass`, kubernetes would set `storageclassname: ""` to those `pvcs`
if `storageclassname: ""` defined in `pvc` and then you enable `defaultstorageclass`, kubernetes won't update those `pvcs` as those are fine with the right `:""`


- 3: create `storageclass` static with `allowedtopologies`
- 4: create `dynamic` way `storageclass`

explain: `storageclass`(storageclass.yaml) is not indicating the `capacity`, but the `pvc`(pvc.yaml) would indicate `capacity` (`resources` -> `request` -> `storage`)
  and then the pod would reference that `pvc`.
  this is how the `pod` would get request resources satisfied and volume mounted ('persistentvolumeclaim' -> `claimname`).
  `pv` would be created automatically (`dynamic`) by kubernetes.

- 5: do maybe something different to show when we use or not `volumebindingmode: waitforfirstconsumer` on `storageclass` just to focus on:
    `selector`(on `pvcs`),
    `afinity`(on `pvs` to restrict on which nodes can use this `pv`),
    `allowedtopologies`(on `storageclass` which are not namespaced but could be used to have restriction in which nodes those classes can be used using `allowedtopologies`)
    `nodeselector`, `affinity`, or `topologyspreadconstraints` (on `pod` in combinaison with the other ones to have fine grained control on where scheduler lands `pods`)
    ``
+---------------+-------+----+
| field/concept| pvc| pv |
+---------------+-------+----+
| namespaced| ✅ yes| ❌ no |
+---------------+-------+-------+
| selector:| ✅ yes (to match pv labels)| ❌ no |
+---------------+-------------------------------+-------+
| labels:| ✅ yes| ✅ yes |
+---------------+---------------+--------+
| nodeaffinity| ❌ no| ✅ yes |
+---------------+-------+--------+
| storageclassname:| ✅ yes | ✅ yes |
+-----------------------+--------+--------+

- static: here create my `pv` and introduce the use of `storageclass` and just use the strictly binded rule and can introduce the idea of `default storage class`
- dynamic: here don't create `pv` and `usestorageclass` only and use the affinity, topology examples and show how scheduler is skipped

static > storageclass > dynamic > topology > affinity + topology > csi driver (rancher)

# capacity 
persistentvolume and persistentvolumeclaim definitions:

unitmeaningnotes
kikibibyte (2¹⁰ bytes)1 ki = 1024 bytes
mimebibyte (2²⁰ bytes)1 mi = 1024 ki = 1,048,576 bytes
gigibibyte (2³⁰ bytes)1 gi = 1024 mi = 1,073,741,824 bytes
titebibyte (2⁴⁰ bytes)rarely used in small clusters
pipebibyte (2⁵⁰ bytes)very large storage
only binary si units (with i) like gi, mi, ki are supported and recommended in kubernetes `yaml`.

# scenario 1 (static)
here we have affinity set on the `pv` and at the same time in the `storageclass` we will set the `volumebindingmode: waitforfirstconsumer` 
so that scheduler will have the responsibility to check on nodes available and not be bypassed

- `cat storage-class-waitforfirstconsumer.yaml`
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: local-storage
# indicates that this storageclass does not support automatic provisioning
provisioner: kubernetes.io/no-provisioner
volumebindingmode: waitforfirstconsumer
```

- `cat pv-local.yaml` 
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: local-pv-with-mandatory-affinity-set
spec:
  capacity:
    storage: 512ki
  # use `block` for ssds for eg:.
  volumemode: filesystem
  accessmodes:
    # rwo: `single node` mount, can be `red and written` by all pods living on that node
    - readwriteonce
  # `delete/retain also recycle but be carefull as it uses `rm -rf` and is only for `nfs` and `hostpath``
  persistentvolumereclaimpolicy: delete
  # play with this field to show behavior of by-passing scheduler and also another of `defaultstorageclass`
  # storageclassname: ""
  storageclassname: local-storage
  # using here `local` which makes us then obliged to use node affinity
  local:
    # this path need to be created manually on node
    path: /tmp/local-pv
  # here creating the node affinity constraint
  nodeaffinity:
    # required or preferred
    required:
      nodeselectorterms:
      - matchexpressions:
        # kubernetes ones
        #- key: kubernetes.io/hostname
        # custom
        - key: location
          operator: in
          values:
          - shizuoka
```

- `cat pvc-without-selector.yaml`
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: pvc-scheduled-in-node-affinity-defined-by-pv-affinity
spec:
  accessmodes:
    - readwriteonce
  volumemode: filesystem
  resources:
    requests:
      storage: 512ki
  storageclassname: local-storage
```

- `cat pod-requesting-storage.yaml` 
```yaml
apiversion: v1
kind: pod
metadata:
  name: pod-needing-storage
spec:
  containers:
    - name: i-need-storage-pod
      image: nginx
      volumemounts:
      # here using mountpath
      - mountpath: "/tmp/local-pv"
        name: my-local-storage
  volumes:
    - name: my-local-storage
      persistentvolumeclaim:
        claimname: pvc-scheduled-in-node-affinity-defined-by-pv-affinity
```

- one `node2`: 
```bash
mkdir /tmpt/local-pv
````
- label `node2`:
```bash
k label node node2.creditzens.net lcoation=shizuoka
```
- make sure the node is labelled acording to the affinity of the pod and then apply `storageclass`, `pv`, `pvc` and `pod` to the cluster
```bash
k apply -f <filename>
... # do the same will all of those files
```
- here normally the pod will be scheduled in node2 which has the label corresponding to the affinity of the `pv`
```bash
 k get pods -o wide
name                  ready   status    restarts   age    ip               node                    nominated node   readiness gates
pod-needing-storage   1/1     running   0          153m   172.16.210.124   node2.creditizens.net   <none>           <none>
```
- then `exec` in `pod` to create a file with content at the volume location `/tmp/local-pv`
```bash
k exec -it pod-needing-storage -- bash
root@pod-needing-storage:/# echo "junko shibuya" > /tmp/local-pv/junko-location-now.txt
```
- now go in `node2` and you will see the file and its content in the `pv` volume located at `/tmp/local-pv`
```bash
creditizens@node2:~$ cat /tmp/local-pv/junko-location-now.txt 
junko shibuya
```
**note:**:
- the `pv` and `pvc` would still reference to each others and be bound even if pod is deleted, so they need to be delete separately and manually
-  the volume on the `node2` is not deleted by kubernetes as it is made to persist if there is `pod` failure. so need also to be deleted manually.


# scenario 2 (from static to dynamic):

here will be showing:
- how pv bind to storageclasses: using `storageclassname: ""` and `# storageclassname: ` not set
- how we need a provisioner and install rancher or show how to install it, then use dynamic provisioning showing no need to create `pv`
- after can maybe show more topology and how to use it
- after move to `dynamic` fully and now no more `affinity` to control where pod would be deployed, no more control but use `topology` on `storageclass`
  to show that this is a way to control where those pods would be deployed.
always show where is the volume created as with `rancher` `local-path` provisioner we don't get it at the path of `pv` as here it is dynamic and 
we don't create `pvs` so the provisioner will be putting the volumes at `/opt/local-path-provisioner/pvc-<numbers>...`.
so need here to describe the `pv` created automatically by the provisioner.

### install `local-path` provisioner (rancher)
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### patch it as `default`
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### use `storageclassname: local-path`
in your created `pvc` use `storageclassname: local-path`

- `pvc`s
```yaml
apiversion: v1
kind: persistentvolumeclaim
metadata:
  name: pvc-following-node-affinity-defined-in-pv-with-or-without-storageclass
spec:
  accessmodes:
    - readwriteonce
  volumemode: filesystem
  resources:
    requests:
      storage: 512ki
  # if no storageclassname defined kubernetes assumes `dynamic` type of provisioning so need to change the provisioner on storageclass
  # storageclassname: ""
  # this is the rancher dynamic provisioner
  storageclassname: local-path

  # `selector` can be defined with `matchlabels` and `matchexpressions`
```

- `pv`s
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: local-pv-with-mandatory-affinity-set
spec:
  capacity:
    storage: 512ki
  # use `block` for ssds for eg:.
  volumemode: filesystem
  accessmodes:
    # rwo: `single node` mount, can be `red and written` by all pods living on that node
    - readwriteonce
  # `delete/retain also recycle but be carefull as it uses `rm -rf` and is only for `nfs` and `hostpath``
  persistentvolumereclaimpolicy: delete
  # play with this field to show behavior of by-passing scheduler and also another of `defaultstorageclass`
  #storageclassname: ""
  storageclassname: local-storage
  # using here `local` which makes us then obliged to use node affinity
  local:
    # this path need to be created manually on node
    path: /tmp/local-pv
  # here creating the node affinity constraint
  nodeaffinity:
    # required or preferred
    required:
      nodeselectorterms:
      - matchexpressions:
        # custom
        - key: location
          operator: exists
```
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: local-pv-2-with-mandatory-affinity-set
spec:
  capacity:
    storage: 512ki
  volumemode: filesystem
  accessmodes:
    - readwriteonce
  persistentvolumereclaimpolicy: delete
  #storageclassname: ""
  # storageclassname: local-storage
  local:
    path: /tmp/local-pv
  nodeaffinity:
    required:
      nodeselectorterms:
      - matchexpressions:
        # custom
        - key: location
          operator: exists
```
```yaml
apiversion: v1
kind: persistentvolume
metadata:
  name: local-pv-3-with-mandatory-affinity-set
spec:
  capacity:
    storage: 512ki
  volumemode: filesystem
  accessmodes:
    - readwriteonce
  persistentvolumereclaimpolicy: delete
  storageclassname: ""
  # storageclassname: local-storage
  local:
    path: /tmp/local-pv
  nodeaffinity:
    required:
      nodeselectorterms:
      - matchexpressions:
        # custom
        - key: location
          operator: exists
```

- `storageclass`es
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: local-storage
# indicates that this storageclass does not support automatic provisioning
provisioner: kubernetes.io/no-provisioner
#volumebindingmode: waitforfirstconsumer
```
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: local-storage2
provisioner: kubernetes.io/no-provisioner
#volumebindingmode: waitforfirstconsumer
```
a way to create a default `storageclass` using the annotation but will not work on creating volume for the `pod` to consume
will just bind to `pvc` as it is expecting `dynamic` provisioning so need to install a dynamic provisioner
so here could use the `rancher` provisioner `local-path`
```yaml
apiversion: storage.k8s.io/v1
kind: storageclass
metadata:
  name: local-storage3-with-annotation-default
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
# indicates that this storageclass does not support automatic provisioning
provisioner: kubernetes.io/no-provisioner
#volumebindingmode: waitforfirstconsumer
```
 this is how to install the `storageclass` from `rancher` `local-path` and then patch it to become `default` but can create more than one after that
so manually create `storageclasses` using `yaml` file and with different names but same `provisioner: local-path`
```yaml
# rancher local path provisioner (storageclass, deployment, configmap)
# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
# kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

