# Resource Limits

soource: (doc resources limites)[https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/]

`cpu` and `memory` limits can be set at the `container` level, the `pod` level (not in the version I am using now 1.28 but in the latest 1.32 yes and will be updating the cluster later to it using a rust coded custom app that upgrades kubernetes cluster just by providing kubelet and kubeadm and containerd desired versions). Also it can be set at `namespace` level.


## Limits, Requests, Hugepages, EmptyDir, Ephemeral-Storage

### Limits
- `limits`: is the maximum that the resource can consume and it is a:
  - `cpu`: Hard limit (`cpu` throttling)
  - `memory`: Not hard limit **but when resource consume too much there is a `OOM` (Out Of Memory) kill process that is done in the `kernel`**
              Therefore, here a container can use more than its limit and the kernel can kill it if there is memory pressure.

### Requests
- `requests`: is the minimum that the resource is consuming.

### Hugepages
- `hugepages-2Mi`: can also be used but alone so not in conjunction with `cpu` and `memory` and this would need to be customized as sytem default `pages`
                   are 4Ki and you might want to use that because you want better performance and have bigger pages so that data is processed in bigger chunks.
                   `hugepages` are a separate pool of memory reserverd at the `os` level.

- reduces `cpu` usage with those bigger chunks. here it from default `4Ki` pages, page would be `2Mi` chunks and there is also another one `hugepages-1Gi` (bigger chunks, but we are not going to use it here).
From ChatGPT: `Reducing Translation Lookaside Buffer (TLB) misses. Reducing CPU cycles wasted in virtual-to-physical memory mapping` 
  - typically used only for specific workload: `databases`, `in-memory caches like Redis`, `virtual machines`, `AI models`, or `networking software`.
  - eg. This tells the scheduler: "Schedule this pod on a node that has 512Mi worth of 2Mi hugepages."
  ```yaml
  requests:
    hugepages-2Mi: 512Mi
  limits:
    hugepages-2Mi: 512Mi
  ```

- if you want to use `hugepages` **with** `cpu` or `memory` or both, you need to have another container in your spec. that would be dedicated to limit the pod usage of those resources, so no effect ont hat specific container but would be taken into account by the sceduler when performing calculation of resources limits totals and policies enforcements on resources usage in `namespace` for eg. here. 

- need also to **change the settings** of `GRUB` in the node itself adding line in config file:
  ```bash
  # append to `GRUB_CMDLINE_LINUX`: `default_hugepagesz=2M hugepagesz=2M hugepages=512`
  # This allocates 512 x 2MB = 1GB of hugepage memory at boot.
  default_hugepagesz=2M hugepagesz=2M hugepages=512
  ```

- check this example where it is not set as custom:
```bash
cat /proc/meminfo

Outputs:
MemTotal:        3961464 kB
MemFree:          406324 kB
MemAvailable:    2053944 kB
Buffers:           56092 kB
Cached:          1795716 kB
SwapCached:            0 kB
Active:          2003880 kB
Inactive:         963176 kB
Active(anon):    1021784 kB
Inactive(anon):   133900 kB
Active(file):     982096 kB
Inactive(file):   829276 kB
Unevictable:           0 kB
Mlocked:               0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
Zswap:                 0 kB
Zswapped:              0 kB
Dirty:                72 kB
Writeback:             0 kB
AnonPages:       1115248 kB
Mapped:           826060 kB
Shmem:             40436 kB
KReclaimable:      81552 kB
Slab:             254520 kB
SReclaimable:      81552 kB
SUnreclaim:       172968 kB
KernelStack:       15584 kB
PageTables:        25608 kB
SecPageTables:         0 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:     1980732 kB
Committed_AS:    6044628 kB
VmallocTotal:   34359738367 kB
VmallocUsed:       37396 kB
VmallocChunk:          0 kB
Percpu:           118272 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:         0 kB
FilePmdMapped:         0 kB
Unaccepted:            0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
DirectMap4k:      169792 kB
DirectMap2M:     4024320 kB
DirectMap1G:     2097152 kB
```

- From ChatGPT, advantages of `hugepages`:
```bash
Using hugepages (2MB or 1GB):
- Fewer pages = fewer entries in the page table
- Less overhead in TLB/cache misses
- Better memory access speed and CPU efficiency
```

- how to setup custom HugePages on the linux node:
Edit the kernel boot parameters (via GRUB):
```bash
sudo nano /etc/default/grub
```
Add this to `GRUB_CMDLINE_LINUX` to reserve 512 `hugepages` of 2MB each = 1GB of `RAM` 
```bash
default_hugepagesz=2M hugepagesz=2M hugepages=512
```
Then update GRUB and reboot:
```bash
sudo update-grub
sudo reboot
```
Verify the Node Reservation after reboot:
```bash
grep Huge /proc/meminfo
```
rollback:
```bash
sudo nano /etc/default/grub
# Remove or comment:
# default_hugepagesz=2M hugepagesz=2M hugepages=512
```
Re-run:
```bash
sudo update-grub
sudo reboot
```

- `yaml` file example for one pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hugepages-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    resources:
      limits:
        # 128 x 2Mi hugepages = 256Mi
        hugepages-2Mi: 256Mi
  restartPolicy: Never
```

### EmptyDir
- The use of `emptyDir` in `volumes` to share data between pods could be problematic if not controlled as there is no cap in how much resource it would use.
  on the `node`. Therefore, we need to control that with some limits.

- `ephemeral-storage` way:
`emptyDir` is under the hood using `ephemeral-storage` so we can play with that resource to limit its usage.(resume)

Volumes can be a local path or can be also in `RAM` so the volume is there but `ephemeral`. We will see `ephemeral-storage` after for the resource limitation of it but can use actualy that to limit the usage of `emptyDir` resources as the pod would be killed by kubernetes if it uses more resources than the limits allowed one the `ephemeral- storage` resource. (`cpu`, `memory`, `ephemeral-storage` are all also resources, keep this in mind)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limit-ephemeral
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "dd if=/dev/zero of=/data/file bs=1M count=500"]
    volumeMounts:
    - mountPath: /data
      name: cache-volume
    resources:
      requests:
        ephemeral-storage: "200Mi"
      limits:
        # this would be used as limit for the `volumes.emptyDir`
        ephemeral-storage: "500Mi"
  volumes:
  - name: cache-volume
    # now this volume is limited to the `spec.containers[0].resources.limits.ephemeral-storage` of 500Mi, more use would kill the pod
    # after it depends on its restart policy or type of pod...
    emptyDir: {}
````

- `sizeLimit` way:
**Works only when `ephemeral-storage` limit is set OR `medium` is used otherwise it is ignored if no `medium` is used and no `ephemeral-storage` is used.**
We can also set a size limit on the `emptyDir` `volumes`
In the next example we bind this `emptyDir` path to the `RAM` using `medium: Memory` option. So it will be here limited to `sizeLimit: 64Mi`.
If we don't use the option `medium: Memory` (`RAM`-based temporary volume) it will be just using the underlying physical filesystem so `disk` or `ssd` depend on the path indicated and node connected resources made available.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ram-cache
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Hello > /cache/hello && sleep 3600"]
    volumeMounts:
    - name: ram-vol
      mountPath: /cache
  volumes:
  - name: ram-vol
    emptyDir:
      # this option would be using in-`RAM` `Memory` for this `ephemeral-storage` (udner the hood)
      medium: Memory
      sizeLimit: 64Mi
```

### Ephemeral-Storage
This is what is used under the hood by `emptyDir`, `logs`, `image layers` and more...
On `ephemeral-storage` can be set `limits` and `requests` and also what is nice here is that it **CAN** be used in combinaison of `cpu` and `memory` resources `limits/requests`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-limits-example
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Hello Junko && sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name:  some-volume-normally-not-limited-but-here-limites-by-epheremal-storage
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
        ephemeral-storage: "100Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
        ephemeral-storage: "500Mi"
  volumes:
  - name: some-volume-normally-not-limited-but-here-limites-by-epheremal-storage
    emptyDir: {}
```

## Kubernetes Units For Calculating `RAM` and `CPU`

### Units Used For Resource Limits Indication: Base-10, Base-2 for RAM (memory)
We have two different ways that it is calculated depending on if it is `decimal` base-10, based calculation of `bytes`, or `binary` base-2 (more precise), based calculations.
So here have to understand that to calculate `RAM` (memory) we can use different ways, one being more precise thant the other (base-2 binary more precise (`i`)).
They both use different units.
- Decimal units10-> 1M = 1,000,000 -> expressed: k, M, G, etc.
- Binary units21Mi = 1,048,576 -> expressed: Ki, Mi, Gi, etc.

Using the documentation example, let's explain how it is calculated:
```bash
128974848  
129e6  
129M  
123Mi
```
- 128974848 (`raw bytes`)
This is already in bytes.
```bash
128,974,848 bytes
```
- 129e6 (scientific notation = 129 million `decimal`)
```bash
129e6 = 129 * 10^6 = 129,000,000 bytes
```
- 129M (129 megabytes in base 10 `decimal`)
```bash
129M = 129 * 1,000,000 = 129,000,000 bytes
```
- 123Mi (123 mebibytes in base 2 `binary`)
```bash
123Mi = 123 * 1,048,576 = 128,974,848 bytes
# got that follwoing this logic:
1 MiB = 1024 KiB
1 KiB = 1024 bytes
# So,
1 MiB = 1024 × 1024 bytes = 1,048,576 bytes
```
Exactly equals the raw byte value: 128974848

### Unit used for resource calculation `CPU` this time:
Here we will just use `millicores`:
- cpu: 500m = 0.5 vCPU -> Half-core
- cpu: 1 = 1 vCPU -> full 1 core
**Never use Mi, Gi, M, or G with CPU** like we did for `RAM`

### Example for both
```yaml
# CPU Example (1 full CPU core)
resources:
  requests:
    cpu: "1"
  limits:
    cpu: "2"

# Memory Example (binary-based)
resources:
  requests:
    memory: "512Mi"
  limits:
    memory: "1Gi"

# Ephemeral Storage Example (decimal-based)
resources:
  limits:
    ephemeral-storage: "1G"

```


## Limit Ranges & Resource Quotas
source: (Doc for limit ranges)[https://kubernetes.io/docs/concepts/policy/limit-range/]

### LimitRange
It is a `namespaced` resource.
```bash
k api-resources | grep "limitranges"
limitranges                       limits       v1                                     true         LimitRange
```

- `LimitRange`:
  - Per-container or per-pod **`default`** `request/limit` values.
  - It does **not enforce a total cap** on the namespace.
  - it is going to **enforce** the `limits` set to it at `pod` `admission` stage and not on `running` `pods`.
  - there can be more than one `LimitRange` resource deployed to same namespace we don't know which will be used as `default`

So here it is just a `default` not something that is going to enforce anything.
It will for example, when you deploy a resource without any `limits` or `requests` nor any, put a `default` value for that resource.
So we can create some `LimitRange` in order to have `default` that we decide how much those are for some resources.
And only **new** `pods` on `admission` would be accepted or rejected (`403 forbidden`) following `limits` set in `LimitRange`
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-resource-constraint
spec:
  limits:
  # here only `cpu` resources is set
  - default:
      cpu: 500m
    defaultRequest:
      cpu: 500m
    max:
      cpu: "1"
    min:
      cpu: 100m
    # limit on resource `container`
    type: Container
```
so if pod only have `requests` (min) limit set on `cpu` the other `limits` (max) will be set and given by the `default` `LimitRange` set `cpu` `limits`
```yaml
# inital `pod` applied to cluster by user
resources:
  requests:
    cpu: 200m
# final `pod ` spec.container[].resources`
resources:
  requests:
    cpu: 200m
  limits:
    cpu: 500m  # from LimitRange
```

**Example `LimitRange` for `pod` at the `namespace-level`**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: pod-limit-range
spec:
  limits:
  - type: Pod
    max:
      cpu: "2"
      memory: "4Gi"
```



### ResourceQuota
source (doc resource quota)[https://kubernetes.io/docs/concepts/policy/resource-quotas/]
it is a `namespaces` resource:
```bash
k api-resources | grep "resorucequota"
resourcequotas                    quota        v1                                     true         ResourceQuota
```

- `ResourceQuota`
While **`ResourceQuota`** **will enforce** `limits` on a `namespace` (in the `default` namespace in our exampel below as we didn't specify `namespace` in `metadata`). This is total sum of what all the resources in the `namespace` can consume `requests` if fine and can be passed over but `limits` not. so we have like that a range `min` `requests` and `max` `limits`.
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    limits.cpu: "4"
    requests.memory: "2Gi"
    limits.memory: "4Gi"
```

Another ResourceQuota now not in `default` `namespace` so need to indicate the `namespace` in `metadata`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    limits.cpu: "4"
    requests.memory: "2Gi"
    limits.memory: "4Gi"
```

- can set a priorityclass in `ResourceQuota` and `pods` could then reference any of those to group `pods` in a `certain` `policy` way of using `ResourceQuota`
Here an exampel of several `ResourceQuota` from the doc defined:
```yaml
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-high
  spec:
    hard:
      cpu: "1000"
      memory: "200Gi"
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values: ["high"]
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-medium
  spec:
    hard:
      cpu: "10"
      memory: "20Gi"
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values: ["medium"]
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-low
  spec:
    hard:
      cpu: "5"
      memory: "10Gi"
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values: ["low"]

```
then the `pod` would reference one of those `ResourceQuota`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-priority
spec:
  containers:
  - name: high-priority
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo hello; sleep 10;done"]
    resources:
      requests:
        memory: "10Gi"
        cpu: "500m"
      limits:
        memory: "10Gi"
        cpu: "500m"
  priorityClassName: high
```

#### `scopeSelector` to track specific resources and restrict
So here it is a way to have a more fine grained control on resources `limits` consumption.

- resources tracked and that can be restricted:
```markdown
pods
cpu
memory
ephemeral-storage
limits.cpu
limits.memory
limits.ephemeral-storage
requests.cpu
requests.memory
requests.ephemeral-storage
```
Here we **restrict** for all `pods` in `namespace` `default` to use `crossNamespaceAffinity`
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: disable-cross-namespace-affinity
  namespace: foo-ns
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
    - scopeName: CrossNamespacePodAffinity
      operator: Exists
```
- `operator`:
```markdown
In
NotIn
Exists
DoesNotExist
```
- `scopeName` requiring to use `operator: Exists`:
```markdown
Terminating
NotTerminating
BestEffort
NotBestEffort
```
- `scopeName` not requiring to use `operator: Exists`:
```markdown
CrossNamespacePodAffinity
PriorityClass
```
- if `operator: In/NotIn` we have to indicate `values`:
```yaml
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values:
          - middle
```

- example `pods` in `namespace` not allowed to have 'cross namespaces affinity'
example for doc that make `pod` limited to their own namespace `foo-ns` the pods created in `` as they won't be able to use `CrossNamespacePodAffinity`
as `spec.hard.pods: "0"`. so no `pod` is allowed to be in affinity out of the namespace `foo-ns`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: disable-cross-namespace-affinity
  namespace: foo-ns
spec:
  hard:
    pods: "0"
  scopeSelector:
    matchExpressions:
    - scopeName: CrossNamespacePodAffinity
      operator: Exists
```
- example *advanced** configuring `kube-apiserver`
`CrossNamespacePodAffinity` can be set as a **limited resource** by setting the `kube-apiserver` flag `--admission-control-config-file` 
where we would indicate the path of where is the below `yaml` file `kind: AdmissinConfiguration`

Here pods can use `namespaces` and `namespaceSelector` in `pod affinity` **only** if the `namespace` where they are created have a `ResourceQuota` object 
with `CrossNamespacePodAffinity` `scopeName` and a `hard` `limit` **greater than or equal to the number of pods** using those fields.

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: "ResourceQuota"
  configuration:
    apiVersion: apiserver.config.k8s.io/v1
    kind: ResourceQuotaConfiguration
    limitedResources:
    - resource: pods
      matchScopes:
      - scopeName: CrossNamespacePodAffinity
        operator: Exists
```

- some other examples of `ResourceQuota` from ducomentation to understand it more, but need to check documentation for more advanced stuff like default `PriorityClass` consumption
(eg.: compute-resources.yaml)
```yaml apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
    requests.nvidia.com/gpu: 4
```

(eg.: object-counts.yaml from doc. but can also put all together in one `ResourceQuota` file)
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
spec:
  hard:
    configmaps: "10"
    persistentvolumeclaims: "4"
    pods: "4"
    replicationcontrollers: "20"
    secrets: "10"
    services: "10"
    services.loadbalancers: "2"
```

### Example LimitRange Interaction and Logic With ResourceQuota
- example of rules and how `pod` `scheduling` would react to `LimitRange` and `ResourceQuota` set in same `namespace`:
we have: 
A `LimitRange` that sets default `cpu` `requests` = 150m, `limits` = 500m
A `ResourceQuota` that says `limits.cpu` = 2

We launch **5** `pods` with no `cpu` `requests/limits` in their specs.
Due to the default values from the `LimitRange`, each one gets 500m limit.

Now:
5 `pods` × 500m `limits` = 2500m = 2.5 cores
But your `ResourceQuota` is only 2 cores!

Result: The 5th `pod` will **not be scheduled** — even though it has valid `limits`, because it would **exceed the `namespace` `ResourceQuota`**.

### RuntimeClass
check `Runtime` running on specific `node`:
```bash
kubectl get node node1.creditizens.net -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}'
Outputs:
containerd://1.7.25
```

`RuntimeClass` is to allocate resources to the runtime used, I use `runc` (as the `handler`) which is default to `containerd` `CNI` (container runtime interface) as the `container runtime` and we call allocated resources to it as well:

Supported Alternatives (`Pod-level` resource usage)
`pod` Overhead (with `RuntimeClass`)
`RuntimeClass` is a `cluster` scope resource and not `namespaced`
When using `RuntimeClass` (e.g. of others other than `runc`: `gvisor` or `kata-containers`), 
you can define a `Pod-level overhead`, which **adds additional `cpu/memory` usage per `pod`**:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: my-runtime
handler: runc
overhead:
  podFixed:
    memory: "128Mi"
    cpu: "250m"
```
Then reference it in your Pod:
```yaml
spec:
  runtimeClassName: my-runtime
```

**Important to know about `RuntimeClass`**
- All configs of our runtime `containerd` are here: `/etc/containerd/config.toml` and this is where it is also named `runc` for the handler name to reference `containerd` as runtime.(`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.${HANDLER_NAME}]`)
- Also `RuntimeClass` accepts scheduling option to make sure that `pods` end out in nodes having the correct `label` which tells that a certain `Runtime` is ready and installed on that `node` using for example `runtimeclass.scheduling.nodeSelector`. Also if `node` have a `taint`, `toleration` can be set in `RuntimeClass`. Here also the intersection between `RuntimeClass`, `Pod`, `Node`, selectors/taints/tolerations would affect `pod` to where the right `Runtime` `handler` is installed. If it is not matching `pod` will be **evicted**. And all is done **at `pod` admission** stage. So lot of checks and more control over where workload ends out to run.
- `RuntimeClass` selects the container runtime handler to use for running the Pod.
- `RuntimeClass` does not control or enforce CPU, memory, or storage limits.
- `RuntimeClass` is not a resource quota or limit in itself.
- `ValidationAdmissionPolicy` could be used to restrict `pod` to a certain `namespace` using `RuntimeClass` but it is not what we are going to see here, we might see `ValidationAdmissionPolicy` in another chapter by itself for max `ReplicaSet` on `Deployments` policy limitation creation.

- `RuntimeClass` can be used in `pod` where you **NEED TO** set `requests` and `limits` for the `pod` resources consumption.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  runtimeClassName: my-runtime
  containers:
  - name: app
    image: myapp
    resources:
      requests:
        cpu: "500m"
        memory: "256Mi"
      limits:
        cpu: "1"
        memory: "512Mi"

```
- get `RuntimeClasses`:
but here normally you would not see anything as Kubernetes by default doesn't create a `RuntimeClass`.
This is something special that need to be set in `kubelet` config and use a special `admission` and probably activate a `feature gate` like `PodOverhead` for eg..
```bash
kubectl get runtimeclass
```
So the feature gate `PodOverhead` is enabled by default in kubernetes v1.28, but it can be manually activated in `kubelet` yaml file, by adding:
```yaml
# /var/lib/kubelet/config.yaml
--feature-gates=PodOverhead=true
# then restart kubelet
sudo systemctl restart kubelet
```

So why would I need to set an `pod` `overhead` to allocate resources for the `runtime` used by containers?
Because some runtime use some `cpu` and `memory` and it is not counted by `scheduler` so pod might look like `cheaper` in resources which can create `OOM Kills` or `CPU starvation` so we might want to have full control as with 2 pods it is fine but with 20000 pods it will have an impact so we **limit and indicate** how much resource can be used by the `runtime` and `scheduler` will take it into account in its calculation. therefore, better `pod` repartition accros `nodes`. 

### Scenarios

#### Scenarios analysis before decision on scenario:
`cpu` and `memory` units used and how it is calculated:
RAM -> decimal 10 based -> Decimal units 10 -> 1M = 1,000,000 -> expressed: k, M, G, etc.
RAM -> decimal 2 based -> Binary units 2 1Mi = 1,048,576 -> expressed: Ki, Mi, Gi, etc.

128974848 (raw bytes) This is already in bytes.
128,974,848 bytes

129e6 (scientific notation = 129 million decimal)
129e6 = 129 * 10^6 = 129,000,000 bytes

129M (129 megabytes in base 10 decimal)
129M = 129 * 1,000,000 = 129,000,000 bytes

123Mi (123 mebibytes in base 2 binary)
123Mi = 123 * 1,048,576 = 128,974,848 bytes (1 MiB = 1024 KiB -> 1 KiB = 1024 bytes, So 1 MiB = 1024 × 1024 bytes = 1,048,576 bytes)

CPU: just use milicores `m` of `integers` without any `m` so it will imply full cores.

then here just show normal resource request/limits
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-priority
spec:
  containers:
  - name: high-priority
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo hello; sleep 10;done"]
    resources:
      requests:
        memory: "10Gi"
        cpu: "500m"
      limits:
        memory: "10Gi"
        cpu: "500m"
    # CPU Example (1 full CPU core)
    resources:
      requests:
        cpu: "1"
      limits:
        cpu: "2"

    # Memory Example (binary-based)
    resources:
      requests:
        memory: "512Mi"
      limits:
        memory: "1Gi"

    # Ephemeral Storage Example (decimal-based)
    resources:
      limits:
        ephemeral-storage: "1G"
```

- cat resource_request_limit_1_mormal.yaml 
can probably work this example to explain step by step what need to be installed and options to put in place `GRUB`,
`metric-server`, and then run it, find a command that would make the pod use too much resource to be evicted
and have a policy attached to `namespace` and even a gateway for admission with `limitrange`
so that we have one huge scenario which will introduce all step by step. `sizeLimit` for `emptyDir` would also be used would also be used.
`resourceQuota` for `namespace` `limits` and `scope` liked to `pod` which will be part of those `scope` `priorityClassName`.
So need to think in steps to introduce all step by step...
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test
  namespace: limited-resources
spec:
  containers:
  - name: reader
    image: nginx
    volumeMounts:
    - name: special-shared-volumes
      mountPath: /tmp/cache
    resources:
      requests:
        memory: "16Mi"
        cpu: "250m"
      limits:
        memory: "32Mi"
        cpu: "500m"

  # sidecar container as container which will be having limits in resources for eg.
  - name: writer
    image: busybox:1.36.1
    command: ["/bin/sh"]
    args: ["-c", "echo 'rigoleto italian restaurant shibuya' > /tmp/cache/which_restaurant.txt && sleep 3600"]

    volumeMounts:
    - name: special-shared-volumes
      mountPath: /tmp/cache
    # maybe add another container using `hugepages` and show how to set it on linus and how to get rid of it
    # - name: hugepage
      # mountPath: /hugepages

    # resources mixing `ephemeral-storage` and `memory` and `cpu`
    resources:
      # cpu/memory/epheremeral-storate can be set together in request but NO `resquests` for `hugepages`
      requests:
        memory: "1Mi"
        cpu: "500m"
        ephemeral-storage: "1M"
      # cpu/memory/ephemeral-storage/hugepages can all be set together in `limits`
      limits:
        # memory binary-based
        memory: "3Mi"
        # memory deciman-based
        # memory: "3M"
        # memmory scientific-based (pure numeric no need to use M/Mi and for templating from other tools or pragramms can be nice)
        # memory: "3e6"
        cpu: "1"
        # Ephemeral Storage Example (decimal-based)
        ephemeral-storage: "3M"
        # important: with `hugepages` only `limits` are possible to set and not `requests`
        #hugepages-2Mi: 100Mi

  volumes:
  - name: special-shared-volumes
    emptyDir: {}
  # `medium` can be used because only one `hugepage` volume is used in this `yaml` otherwise would just use it `volumes` without the `medium` like: `emptyDir: {}`
  # - name: hugepage
    # emptyDir:
      # medium: HugePages

```


`hugepage` for better cpu usage and side pod with request/limit as can't be set together. `hugepage` can be set on nodeii custom way at :
```bash
# append to `GRUB_CMDLINE_LINUX`: `default_hugepagesz=2M hugepagesz=2M hugepages=512`
sudo nano /etc/default/grub
default_hugepagesz=2M hugepagesz=2M hugepages=512
# Then update GRUB and reboot:
sudo update-grub
sudo reboot
# Verify the Node Reservation after reboot:
grep Huge /proc/meminfo
# delete the line added or comemnt it out and update-grub and reboot to go back to defaut `4Ki` page
```

`emptyDir` issue and how to control
control using `ephemeral-storage` way:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limit-ephemeral
spec:
  containers:
  - name: app
    image: busybox
    # this will write 500 block of 1M resulting in a 500Mi(B) file: it is good to use this command so we can test limit storage
    command: ["sh", "-c", "dd if=/dev/zero of=/data/file bs=1M count=500"]
    volumeMounts:
    - mountPath: /data
      name: cache-volume
    resources:
      requests:
        ephemeral-storage: "200Mi"
      limits:
        # this would be used as limit for the `volumes.emptyDir`
        ephemeral-storage: "500Mi"
  volumes:
  - name: cache-volume
    # now this volume is limited to the `spec.containers[0].resources.limits.ephemeral-storage` of 500Mi, more use would kill the pod
    # after it depends on its restart policy or type of pod...
    emptyDir: {}
```
here in conjunction with `request/limit`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-limits-example
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Hello Junko && sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name:  some-volume-normally-not-limited-but-here-limites-by-epheremal-storage
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
        ephemeral-storage: "100Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
        ephemeral-storage: "500Mi"
  volumes:
  - name: some-volume-normally-not-limited-but-here-limites-by-epheremal-storage
    emptyDir: {}
```
control using `sizeLimit` way:
```yaml
apiVersion: v1
kind: Pod
metadata:
name: ram-cache
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo Hello > /cache/hello && sleep 3600"]
    volumeMounts:
    - name: ram-vol
      mountPath: /cache
  volumes:
  - name: ram-vol
    emptyDir:
      # this option would be using in-`RAM` `Memory` for this `ephemeral-storage` (udner the hood)
      medium: Memory
      sizeLimit: 64Mi
```

use `LimitRange` to set default `resquest/limits` on pods that do not indicate it. tell that is working on pod admission to reject pod scheduling or not, but has is not enforcing anything on pod already running. so if pod have not set one of those the but limit range have set it, it will be set on pod as default.
`container`-level `LimitRange`: 
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-resource-constraint
  namespace: <not need to indicate if `default` namespace used>
spec:
  limits:
  # here only `cpu` resources is set
  - default:
      cpu: 500m
    defaultRequest:
      cpu: 500m
    max:
      cpu: "1"
    min:
      cpu: 100m
    # limit on resource `container`
    type: Container
```
`pod`-level `LimitRange`:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: pod-limit-range
  namespace: <not need to indicate if `default` namespace used>
spec:
  limits:
  - type: Pod
    max:
      cpu: "2"
      memory: "4Gi"
```

limits for resources in the `namespace` total will use `ResourceQuota` for that
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    limits.cpu: "4"
    requests.memory: "2Gi"
    limits.memory: "4Gi"
```
`ResoruceQuota` with `priorityClass` that would be referenced in `pod`:
```yaml
---
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-high
    namespace: junko
  spec:
    hard:
      cpu: "1000"
      memory: "200Gi"
      pods: "10"
  scopeSelector:
      matchExpressions:
      - operator: In
        # can also be `CrossNamespacePodAffinity` to limit pods `CrossNamespacePodAffinity` but we are going to see it here, just look at documentation
        # need to set a `kind: AdmissionConfiguration` for `CrossNamespacePodAffinity` which will set that rule using `api-server` cluster wise but we are not going to see it here.
        scopeName: PriorityClass
        values: ["high"]
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-low
    namespace: junko
  spec:
    hard:
      cpu: "5"
      memory: "10Gi"
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values: ["low"]

---
apiVersion: v1
kind: Pod
metadata:
  name: high-priority
  namespace: junko
spec:
  containers:
  - name: high-priority
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo hello; sleep 10;done"]
    resources:
      requests:
        memory: "10Gi"
        cpu: "500m"
      limits:
        memory: "10Gi"
        cpu: "500m"
  priorityClassName: high
```

talk about `kind: RuntimeClass` taht can be used to have even more control on how much resource are allocated to container runtime as it is not calculated by `scheduler` if not set. while if set it will be considered for pod `scheduling`. when running 2 pods it is fine but when running 20000 pods with different runtimes, those will consume resoruces that can affect performance and create issues of pods being evicted because OOM killes of CPU starvation so another resource consuming RAM and CPU but not calculated correctly creating issues int he cluster. It is better to have full control and leverage kubernetes native scheduler behaviour in our favor by privideing as much detailed information to it before it decides the repartition of the workload in the cluster.


## Issues

### `OCI runtime create failed: ... error setting cgroup config for procHooks process: ... cgroup.controllers: no such file or directory`

- when using `ephemeral-storage` need to have an option activated on the `GRUB`, `/etc/default/grub` file with the var `GRUB_CMDLINE_LINUX` need to add `systemd.unified_cgroup_hierarchy=1`: so i have appended it to already existing options: `GRUB_CMDLINE_LINUX="find_preseed=/preseed.cfg auto noprompt priority=critical locale=en_US systemd.unified_cgroup_hierarchy=1"`
after need to update and reboot:
```bash
sudo update-:grub
sudo reboot
```
then check:
```bash
stat /sys/fs/cgroup/cgroup.controllers
```
lesson: 
  - To make ephemeral-storage requests/limits work on Kubernetes 1.28 + containerd:
    - Kernel >= 5.2 (you have 6.8)
    - GRUB must enable cgroup v2 explicitly, with: `systemd.unified_cgroup_hierarchy=1`
    - `sudo nano /etc/containerd/config.toml` and check that `systemdCgroup` is set to `true`:
    ```bash
    # inside /etc/containerd/config.toml
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
    # restart containerd
    sudo systemctl restart containerd
    ```
    - and check the kernel version `>= 5.8` to be able to use `Cgroup.v2`
    ```bash
    uname -r
    outputs:
    6.8.0-57-generic
    ```

### `error during container init: procReady not received, openat2 ... cgroup.controllers: no such file or directory`
- wehn setting `limits` and `request` if it is too low and even the binary can't startm you will run in `memory` starvation because you provided fewer resoruces than the minimum required. Here `nginx` container has been started with less permitted request than required to start the binary so the pod would never start and gets error.
- `runc` can't finish setting up `Cgroup` therefore exists.

Solution: 
- increase the `memory` `requests` and `limits`
- run a pod discovery meaning create a pod and chech how much resource the container needs by running `k top pod <pod_name>`, then you will see `memory` and `cpu` usage and be able to set it in the `yaml` file, add alsway a buffer of `20%`.
- You can also set a `LimitRange` in order for you to have control on the minimum resource that are requested and limited by pods containers, so that if it is too low pod won;t be passing the `admission` control thanks to the `LimitRange`
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: test
spec:
  limits:
  - default:
      memory: 64Mi
      cpu: 100m
    defaultRequest:
      memory: 32Mi
      cpu: 50m
    type: Container
```
- or use Prometheus/Grafana and see how much pod is using and then you will know roughly what are the `requests` and `limits` to set by taking the average high resoruce use and adding `20%` to be sure.

```bash
k get pods
Outputs:
NAME   READY   STATUS    RESTARTS      AGE
test   1/1     Running   1 (46m ago)   179m

k top pod test
Outputs:
NAME   CPU(cores)   MEMORY(bytes)   
test   0m           13Mi 
```
```bash
k top pod -A
NAMESPACE            NAME                                                 CPU(cores)   MEMORY(bytes)   
kube-system          calico-kube-controllers-85578c44bf-xqlmz             5m           56Mi            
kube-system          calico-node-7m4mc                                    90m          145Mi           
kube-system          calico-node-8v4pl                                    63m          98Mi            
kube-system          calico-node-mmh88                                    62m          145Mi           
kube-system          coredns-5d78c9869d-kpbtn                             3m           28Mi            
kube-system          coredns-5d78c9869d-l47pn                             3m           41Mi            
kube-system          etcd-controller.creditizens.net                      49m          78Mi            
kube-system          kube-apiserver-controller.creditizens.net            125m         317Mi           
kube-system          kube-controller-manager-controller.creditizens.net   31m          124Mi           
kube-system          kube-proxy-88h87                                     21m          61Mi            
kube-system          kube-proxy-bs58j                                     17m          61Mi            
kube-system          kube-proxy-mwnmk                                     13m          60Mi            
kube-system          kube-scheduler-controller.creditizens.net            7m           64Mi            
kube-system          metrics-server-596474b58-hn5tz                       9m           66Mi            
local-path-storage   local-path-provisioner-6548cc785f-wmv98              1m           46Mi
```

### `Metrics-server` activation on cluster to be able to run `k top...` command

isntall
```basg
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
issue here was that the `metrics-server` `pod` in `namespace` `kube-system` intalled wasn't starting but just `running` in `0/1`. So this known issue so need to patch the `deployment` to get it running and then can use th ecommand `k top ...`
**"metrics-server tries to securely scrape kubelet metrics using HTTPS with valid certificates. But in your kubeadm cluster, kubelet uses self-signed certs, and by default, the metrics-server doesn't trust them."**
```bash
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

```

Solution here is to patch it so that it ignores those self-signed certs of `kubeadm cluster`

### where are `emptyDir` shared volumes of contaienr located
- first of all the containers can be checked if running fine using `crictl` the `cli` tool of `containerd`. So first need to check where pod have been scheduled and then `ssh` to the node. and then run `sudo crictl ps -a` to find the container running int he pod and troubleshoot those if any issues.
- if no issues where is the shared volume path int he file system as i have created one at `/tmp/cache` but aren't seeing it when doing `ssh` to `node1.creditizens.net1` where the `pod` has been scheduled?
The location is actually in the `kubelet` folder at path like: `/var/lib/kubelet/pods/<pod-UID>/volumes/kubernetes.io~empty-dir/<volume-name>`
for us:
```bash
ls /var/lib/kubelet/pods/<pod-UID>/volumes/kubernetes.io~empty-dir/special-shared-volumes/
#here is real data on node1.creditizens.net
sudo ls -la /var/lib/kubelet/pods/9d0501b0-e367-41a4-819b-2fba105c16d7/volumes/kubernetes.io~empty-dir/special-shared-volumes
total 12
drwxrwxrwx 2 root root 4096 avril 15 03:43 .
drwxr-xr-x 3 root root 4096 avril 15 03:43 ..
-rw-r--r-- 1 root root   36 avril 15 03:43 which_restaurant.txt
# then
sudo cat /var/lib/kubelet/pods/9d0501b0-e367-41a4-819b-2fba105c16d7/volumes/kubernetes.io~empty-dir/special-shared-volumes/which_restaurant.txt
Outputs:
rigoleto italian restaurant shibuya
```
eg. how to get pod UID:
```bash
kubectl get pods -n limited-resources test -o jsonpath='{.metadata.uid}'
outputs:
9d0501b0-e367-41a4-819b-2fba105c16d7
# OR displya nice columns
kubectl get pods -n limited-resources -o custom-columns=PodName:.metadata.name,PodUID:.metadata.uid
PodName   PodUID
test      9d0501b0-e367-41a4-819b-2fba105c16d7
```

solution: here different from when we were using `storageclass` where in dynamic it was created in the `csi` path for the `pv` or to troubleshot `pvc` at `/var/lib/kubelet/plugins/kubernetes.io/csi/pv/<pv-name>/...` or even in static provisioning where the path needed to exist beforehands on the node corresponding to the same path indicated on the container. 
while here it is in the `kubelet` folder at a certain path for the `emptyDir` to live in and be deleted when pod stops.


## Commands helping to put some **stress on the memory** by increasing the size of resources used
```bash
# can be used in `yaml` files
i=0; while true; do echo "$i - writing some data to fill the volume" >> /cache/file.txt; i=$((i+1)); sleep 0.1; done
```
```bash
# can be ran inside a pod by `exec` into it creating straight away a big file (here 10MiB filesize)
dd if=/dev/zero of=/cache/bigfile bs=1M count=10
```

## Commands to put **stress on cpu**
stress CPU usage inside a container and trigger CPU limits, you can use tools like:

- `yes` command (simplest, built-in)
This will max out one CPU core by continuously printing y.
```bash
yes > /dev/null
```

- `dd` CPU-bound example
This reads and discards data rapidly — very CPU-intensive.
```bash
dd if=/dev/zero of=/dev/null bs=1M
```

- `sh` loop with math (portable)
A tight loop that constantly calculates something.
```bash
sh -c 'while true; do echo $((13*45)); done'
```

- Stress test with stress tool
If image includes stress (like ubuntu, debian, alpine with apk add stress), we can use:
# `--cpu 2`: spin up 2 CPU workers
# `--timeout 60`: run for 60 seconds
```bash
stress --cpu 2 --timeout 60
```

- if container doesn't include it, can use an image like:
```yaml
image: progrium/stress
command: ["stress"]
args: ["--cpu", "2", "--timeout", "60"]
```
(excalidraw walkthrough diagram)[https://excalidraw.com/#json=kR1Z7xUGN7pIUZDpRdOMt,TF01Tb_MHbDPCgbrR-JJlA]
