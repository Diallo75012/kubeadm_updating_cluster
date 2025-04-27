# Init Containers & Sidecar Containers

- `Init Containers`:
  source: (init container doc)[https://kubernetes.io/docs/concepts/workloads/pods/init-containers/]
  - first `kublet` makes `network` and `storage` ready then `init container` can start
  - will always start, run, and finish running before any other container starts
  - if many defined: will start sequentially and one starts when the other is done completely
  - defined in the pod at the container level
  - it is NOT possible to define any king of `..probes` (readiness, liveliness, lifecycle...etc...)
  - BUt `resource limits` and `security` can be defined
  - can be used to set conditions to be met before `pod` starts main container app.
  - can be used to have access to some secrets, or install tools (awk, dig, python...etc...) making the app container lighter
  - can be used to wait for a `service` to be ready or even use pod ip to inject in jinja template for pod configuration necessity
  - can become a `side container` and live as long as pod is alive if a `sidecar container` is defined inside of it
  - shares same `namespace`, `network` and `volumes` (use of `emptyDir`) as the main container app. but not `probes can be defined`
  - changing the `container image` wouldn't restart `pod` but just the `container`

- `Sidecar Containers`:
  source: (sidecar doc)[https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/]
  - unlike `Init Containers` it will be started alongside normal containers
  - it is possible to define `..probe` (readiness, liveliness...etc.., lifecycle), then this probe would be used for the `pod` `probe` like if `readinessProbe` would be used for `pod` `readinessProbe`
  - shares resources with other containers of the same pod application
  - used to set logging, monitoring, data synchronization, security
  - can be an `init container` with `restatPolicy` set to `always` which will make it run during the full lifetime of the pod. OR just a normal pod which is the way to do it normally but make sure it is just to do some side stuff.
  - would be terminated after the main pod container app. and would be created just after `init containers`
  - can be defined inside an `init container` and would live as long as the `pod` is alive. so here here it is like an `init container` that would not exit and next `init container` would start without waiting for this one to exit when the `sidecar` defined inside the `init container` would start
  - lives alongside main container pod and have its own `restarPolicy` and can be `scaled` separately but shares `namespace`, `networking` and `resources` (limits, volumes...) with the `pod`. = `independent lifecycle`

## Scenario 1: Creating a Pod With Init Container Writing Custom Nginx HTML Page

So here instead of using `kind: ConfigMap` as we did in the past, we are going to use an `init container` to customize
the `nginx` `html` page.
It is like making a copy of from the `init container` pod path location of the volume having that cutom `index.html` to the `nginx` `volumeMount` `mountPath` location.
Doing a `port-forward` of the pod would provide access to the browser to show the custom page!

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tower-109-promo-message
  namespace: department-stores
spec:
  volumes:
    - name: html-message
      emptyDir: {}

  initContainers:
    - name: init-html
      # can use custom image if want to have full control
      # meaning that here you would create a container which have copied the necessary files and just retrieve it from it
      image: busybox:1.35
      # command can be `wget` pulling file from the repo git or copy `cp` command to copy from custom image registry or other like copy from filesytem local, can be a jinja file which will be populated by the app container later...etc..
      # here we just `echo` command a sentence simply
      # best practice is to make this command `idempotent` so make sure that file doesn't already exist as we might get an error (not done in this example)
      command: ['sh', '-c', 'echo "<h1 style="color:#800f71">Shibuya 109 is Running a Sakura Promo During April: ALL 30% OFF!!</h1>" > /department-store/109/messages/index.html']
      volumeMounts:
        - name: html-109-message
          mountPath: /department-store/109/messages/

  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        - name: html-109-message
          mountPath: /usr/share/nginx/html
```

- another example: cat tower-109-promo-message.yaml 
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: tower-109-promo-message
  name: tower-109-promo-message
  namespace: department-stores
spec:
  # main container app
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        - name: html-109-message
          mountPath: /usr/share/nginx/html/

  # init container
  initContainers:
      # can use custom image if want to have full control
      # meaning that here you would create a container which have copied the necessary files and just retrieve it from it
    - name: init-109-html
      image: busybox:1.35
      # command can be `wget` pulling file from the repo git or copy `cp` command to copy from custom image registry or other like copy from filesytem local, can be a  jinja file which will be populated by the app container later...etc..
      # here we just `echo` command a sentence simply
      # best practice is to make this command `idempotent` so make sure that file doesn't already exist as we might get an error (not done in this example)
      command: ['sh', '-c', 'echo "<h1 style="color:#800f71">Shibuya 109 is running a Spring Sakura Promo: ALL -30%!!!!</h1>" > /depratment-stores/109/message/html/index.html']
      volumeMounts:
        - name: html-109-message
          mountPath: /depratment-stores/109/message/html/

  # now we need the shared volumes between both
  volumes:
    - name: html-109-message
      emptyDir: {}
```

```bash
# make it available for the browser using exposition type `port-fowrward
kubectl apply -f nginx-with-init.yaml
kubectl port-forward pod/nginx-with-init 8080:80
curl http://localhost:8080
```

### Order Of Execution
The order of `Init Containers`, `Sidecar Containers`, even `pods` is determined by the `resource/limits`
The more resources is asked the first it would be ran.
So always `Init Container` first runs, then it is checked which one has highest `resource/limits` to determine which one starts first, therefore, not rquesting resource and limits, means it is the highest.
Then `Sidecars`, and then `pods` would run and also here `resource/limits` would deternmine in which orderi
Otherwise, for each group it would be done sequentially, in the order of how those are defines in the `yaml` file's `.spec.initContainers`.

### Order of Deletion
When termination pod, first the main application container would stop, then the `sidecars` so it following the inverse order of the execution when starting the pod.

## Scenario 2: Nginx logs are being capture by a sidecar container (2 ways)
- way 1: `sidecar container` is an `init container` with `restartPolicy` equal to `always`
- way 2: `sidecar container` is a normal pod capturing nginx logs
- Both ways use the technique of setting `emptyDir: {}` for shared volumes between the two (like I do in my `Python` apps when i create a dynamic `.env` file to share data between processes)

### Way 1:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-init-sidecar
spec:
  initContainers:
    - name: log-agent
      image: busybox
      command: ["sh", "-c", "echo '###### running from sidecar Init Container Way ########' > /share/index.html && tail -f /shared/index.html"]
      volumeMounts:
        - name: shared-content
          mountPath: /shared
      restartPolicy: Always  # ✅ THIS IS CRUCIAL

  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        - name: shared-content
          mountPath: /usr/share/nginx/html

  volumes:
    - name: shared-content
      emptyDir: {}
```


**VERY IMPORTANT**
- **Feature SidecarContainers need to be activated on the cluster as of the v1.28.15 of kubeadm it is not activated, after from next version it will be** 
  - **first get the `kubeadm` config file boilerplate and update it for all component activating the feature `SidecarContainers` also adding the controller ip address and the controller hostname as it is ran on the controller node**:
```bash
cat kubeadm_config_to_patch_sidecar_feature_enablement_boilerplate.yaml
```

```yaml
# get this boilerplate file that you need to update manually using: `kubeadm config print init-defaults > kubeadm-config.yaml`
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  ### need to update this to `advertiseAddress:` to the control plane api address running `k get nodes -o wide` or `hostname -I | awk '{print $1}'`
  ### advertiseAddress: 1.2.3.4
  advertiseAddress: 192.168.186.146
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  ### make sure the hsotname matched the controller node one `run: `hostname`` and get the result of that field here
  name: controller.creditizens.net
  taints: null
  ### this activate the sidecar feature
  kubeletExtraArgs:
    feature-gates: "SidecarContainers=true"
---
apiServer:
  timeoutForControlPlane: 4m0s
  ### this to add the feature `SidecarContainers` to the API server
  extraArgs:
    feature-gates: "SidecarContainers=true"
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
### updated controller manager from default `controllerManager: {}` to add the feature `SidecarContainers`
#controllerManager: {}
controllerManager:
  extraArgs:
    feature-gates: "SidecarContainers=true"
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: 1.28.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
### updated scheduler fromd efault `scheduler: {}` to add the feature `SidecarContainers`
#scheduler: {}
scheduler:
  extraArgs:
    feature-gates: "SidecarContainers=true"

# then run : sudo kubeadm upgrade apply <your_kubeadm_actual_version> --config=<name_of_this_pathcer_yaml_file>
```


- After that that worked fine showing that it is activated as otherwise it wouldn't accept the `restartPolicy: Always` inside the `initContainers`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: manga-kissa-abunai
  labels:
    app: manga-kissa-abunai
spec:

  containers:
    - name: proxy-mangakissa
      image: nginx
      volumeMounts:
        - name: mangakissa-shared-volume
          mountPath: /usr/share/nginx/html/

  initContainers:
    - name: log-mangakissa-events
      image: busybox:1.35
      command: ['sh', '-c']
      args:
        - |
          mkdir -p /mangakissa/events/
          echo "*****Running From Init Container: Log-MangaKissa-Events****** \n <h1 style=\"color:red;\">Manga Kissa Abunai!</h1>" > /mangakissa/events/index.html
          sleep 3600
      volumeMounts:
        - name: mangakissa-shared-volume
          mountPath: /mangakissa/events/
      restartPolicy: Always

  volumes:
    - name:  mangakissa-shared-volume
      emptyDir: {}

```

- you can check the `real cluster config and see that `SidecarContainers` feature activation is there and that is why the pod could run without any issues
```bash
kubectl get configmap kubeadm-config -n kube-system -o yaml > real_cluster_config.yaml
cat real_cluster_config.yaml
```
```yaml
apiVersion: v1
data:
  ClusterConfiguration: |
    apiServer:
      extraArgs:
        authorization-mode: Node,RBAC
        feature-gates: SidecarContainers=true
      timeoutForControlPlane: 4m0s
    apiVersion: kubeadm.k8s.io/v1beta3
    certificatesDir: /etc/kubernetes/pki
    clusterName: kubernetes
    controllerManager:
      extraArgs:
        feature-gates: SidecarContainers=true
    dns: {}
    etcd:
      local:
        dataDir: /var/lib/etcd
    imageRepository: registry.k8s.io
    kind: ClusterConfiguration
    kubernetesVersion: v1.28.15
    networking:
      dnsDomain: cluster.local
      serviceSubnet: 10.96.0.0/12
    scheduler:
      extraArgs:
        feature-gates: SidecarContainers=true
kind: ConfigMap
metadata:
  creationTimestamp: "2023-07-07T07:39:53Z"
  name: kubeadm-config
  namespace: kube-system
  resourceVersion: "413627"
  uid: 744a0490-3f7a-4d87-bedd-4b225edd0758
```

### Way 2:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-normal-sidecar
spec:
  # so here we have two containers running and defined, one being a sidecar container
  containers:
    - name: log-agent
      image: busybox
      command: ["sh", "-c", "echo '###### running from sidecar Container Normal Way ########' > /share/index.html && tail -f /shared/index.html"]
      volumeMounts:
        - name: shared-content
          mountPath: /shared

    - name: nginx
      image: nginx
      volumeMounts:
        - name: shared-content
          mountPath: /usr/share/nginx/html

  volumes:
    - name: shared-content
      emptyDir: {}
```

- another example that works fine and contextualized:
```bash
cat sidecar_container_as_sidecar_container_the_normal_one.yaml 
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tokyo-tower-sidecar-info
spec:
  # so here we have two containers running and defined, one being a sidecar container
  containers:
    - name: info-of-the-day
      image: busybox
      command: ["sh", "-c", "echo '###### Tokyo Tower Will Be Opened On The 1st April and This is Not a Joke! ########' > /tokyo-towaaa/info/index.html && tail -f /dev/
null"]
      volumeMounts:
        - name: info-message
          mountPath: /tokyo-towaaa/info/

    - name: nginx
      image: nginx
      volumeMounts:
        - name: info-message
          mountPath: /usr/share/nginx/html

  volumes:
    - name: info-message
      emptyDir: {}
```

### Yaml command to container different ways to do it
. 1) using `args` to put all commands to run `sh -c` accepts command in one line with `&&` as well we will see it after:
```yaml
command: ["sh", "-c"]
args:
  - |
    echo "First command"
    echo "Second command"
    echo "Third command"
```

. 2) as a single line:
```yaml
command: ["sh", "-c", "echo one && echo two && echo three"]
sh -c lets you run multiple shell commands in a single string.
```

. 3) Use a shell script
```yaml
command: ["sh", "/scripts/startup.sh"]
```

### Debug command
- if issues: `kubectl debug pod/manga-kissa-abunai -it --image=busybox --target=log-mangakissa-events`
- make sure you have enabled the feature in your cluster to run sidecars:
```bash
sudo nano /var/lib/kubelet/config.yaml
# then add this:
featureGates:
  SidecarContainers: true
# then restart kubelet
sudo systemctl restart kubelet
```

## REMINDER ON PODS RESTART POLICIES VALUE EFFECTS (ChatGPT)
1. Always (default for Pods)
- Container restarts automatically on failure or exit.
- Used for long-running containers, like web servers.
- Required for Deployments, ReplicaSets, etc.

2. OnFailure
- Restart only if container exits with non-zero code (error).
- Does not restart if the container exits cleanly (exit 0).
- Used in Jobs (batch processing).

3. Never
- Never restarts, no matter how the container exits.
- Used when you want one-shot containers (manual runs, debugging).
