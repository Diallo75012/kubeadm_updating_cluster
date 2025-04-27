# Daemonsets
source: (doc daemonsets)[https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/] ,(doc daemonsets 2)[https://kubernetes.io/docs/tasks/manage-daemon/create-daemon-set/]

let's start first by talking about `priorityClass`
### `priorityClass` rules in order to have a Daemonset higher in priority than workload pods
source: (doc priority class)[https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#non-preempting-priority-class]

a `priorityClass` can be set on any `pod`, but before that we need to create some different ones with different values.
- value range of `priorityClass` is : from `-2147483648` to `1000000000` , the higher the more priority, (admin range)
- name of `priorityClass` is DNS compliant and can't start with `system-` which is reserved for kubernetes controller ones
```bash
k get priorityclasses
Output:
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000000000   false            655d
system-node-critical      2000001000   false            655d
```
- `priorityClass` is not namespaced resource.
- if you want to set a `default` for any `pod` not declaring a `priorityClassNameName` we can set **ONLY IN ONE PRIORITY CLASS** : `globalDefault: true`
  and if no `globalDefault` is set, `pod` not declaring `priorityClassName` would have a value of `0`.

(eg. `priorityClass`)
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-tokyo-mangakissa-location
# if set to `never` pods using this `priorityClass` would be put on the queue without taking advantage on others, but run when resoruces will be available
# so here you want to prioritize those pods but do not want to stop existing ones because of higehr priority but wait until resource is available
# so by default it `preempts` so takes priority on other pods as it is set by default to `preemptLowerPriority` = if you have higher priority `value` be scheduled/run first
preemptionPolicy: Never
# from `-2147483648` to `1000000000` 
value: 1000000
# can be set to `true` for only one `priorityClass` so that any pod created without a declaration of `priorityClassName` will take that priority value
# when no `priorityClass` `globalDefault` set to `true` and pods do not declare `priorityClassName` the pod default `priority` is equal to `0`
globalDefault: false
# description just to tell to admin or user what this priority class can be used for.
description: "This priority class is very high priority one, use it only for Shibuya location pods."
```
- `pod` declaring a `priorityClassName` that doesn't exist **will be rejected**.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-shibuya
  labels:
    mangakissa-level: five
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  priorityClassName: high-tokyo-mangakissa-location
```
- `scheduler` will check first the `priorityClassName` > `value` in `priorityClass` > then order the scheduling from the highest to to the lowest priority.
  So here, **super important** to understant is that if pod is scheduled and `scheduler` finds the right `node`, `pod` is in a `Statud: pending`, it is `pending ` because there is no space for that `high priority pod` but `scheduler` would look at other present `pods` `priority` in order to evict `lower priority` `pods` from the `node` in order to `schedule` the `pending higher priority pod`. **thereofee, be carefull** and understand that for debugging `**why pods got evicted?**`
  And this is an issue, as when those `victim pods` are being evicted, `scheduler` still can put that `high priority pod` in another `node` while the `victims pods` are terminating. So it is something to experience and understand that `scheduler` is still scheduling other pods and if it find space in the meantime for the `pending high priority pod` it will just put the pod where all configs are satisfied. so here you get `pods` terminated and at the same time `nothing` taking their place because of the `timing`... so be careful with standalone pods as no `replicaset` to recreate those... (better use `replicasets`)
  Documentation says to prevent this: "In order to minimize this gap, one can set graceful termination period of lower priority Pods to zero or a small number. PodDisruptionBudget is supported, but not guaranteed"
  Also if `high priority pod` has `inter-pod affinity` with some `lower priority pods` on that `node`, those `pods` won't be `evicted`. so it is more complicated than just follwoing the priority of the `pod`

## `daemonset` fields and rules
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  # `spec.seletor.matchLabels` have to be same as `spec.template.metadata.labels`
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      # can also here specify or `nodeSelector` or `afifinity` and pods daemonsets will be created only on those matching nodes
      # `ANDed` if both indicated `affinity` + `nodeSelector`
      # affinity: ....
      # nodeSelector: ...
      # can choose `scheduler` with `schedulerName`
      # schedulerName: ...
      tolerations:
      # these tolerations are to have the daemonset runnable on control plane nodes
      # remove them if your control plane nodes should not run pods
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /rootfs
          readOnly: true


      # have to be set to `Always` and if not set `default` to always
      restartPolicy: Always   
      # it may be desirable to set a high priority class to ensure that a DaemonSet Pod
      # preempts running Pods
      # priorityClassName: important
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
        path: /var/log
      - name: proc
        hostPath:
        path: /proc
      - name: sys
        hostPath:
        path: /sys
      - name: root
        hostPath:
        path: /
```

## `Prometheus`
You can make a `pod` **scrapable** by prometheus for metrics by adding this `annotations: prometheus.io/scrape: true`

we will use `helm` to deploy prometheus:
- Node Exporter as a DaemonSet (collects node metrics: CPU, memory, disk, network).
- Prometheus server as a Deployment (central scraping and storage).
- Grafana as a Deployment (for dashboards).

so we will need to write a custom values.yaml file and use it to `override/patch` the default `values.yaml` present in the `helm` repo that I am going to use.
```bash
helm install tokyo-mangakissa-monitoring prometheus-community/kube-prometheus-stack -f values.yaml
```
or get the repo, update it, and then download it to be able to see the `values.yaml` file before patching it
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
Outputs:
"prometheus-community" has been added to your repositories

helm repo update
Outputs:
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "prometheus-community" chart repository
Update Complete. ⎈Happy Helming!⎈

helm pull prometheus-community/kube-prometheus-stack --untar
# now a folder `kube-prometheus-stack` will be present with all files in it (can explore)
```

we will need to add `annotations` on `pods` so that we can have `metrics` of `pods` as `prometheus` is getting by default `cpu/memory` form underlying system (default: `node-level` resource scraping).
(eg.: `pod-level` resource scraping)
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
```

- `custom_prometheus_stack_helm_values.yaml `
```yaml
# use command : helm install tokyo-mangakissa-monitoring prometheus-community/kube-prometheus-stack -f custom_prometheus_stack_helm_values.yaml  --namespace monitoring --create-namespace
global:
  scrape_interval: 60s  # scrape every 60 seconds instead of default 15s
  evaluation_interval: 60s  # rule evaluations every 60 seconds

prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: "200Mi"
        cpu: "50m"
      limits:
        memory: "500Mi"
        cpu: "250m"
    retention: "6h"  # (Optional) keep only 6 hours of metrics for lightweight demo
    scrapeInterval: 60s  # Override inside prometheusSpec (some charts allow this too)
    serviceMonitorSelector: {}  # Allow scraping ServiceMonitors if later you add them
  service:
    type: NodePort # patch from `ClusterIp` type to `NodePort`
    nodePort: 30900

nodeExporter:
  resources:
    requests:
      memory: "100Mi"
      cpu: "50m"
    limits:
      memory: "200Mi"
      cpu: "100m"

# grafana to NodePort and access it on port `32000`
grafana:
  service:
    type: NodePort
    nodePort: 32000  # or any available port between 30000–32767

```
- then get the repository and update your local helm repo and install it on the fly with name `tokyo-mangakissa-monitoring ` and flag `--create-namespace` which will create the `namespace` `monitoring` on the fly.
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install tokyo-mangakissa-monitoring prometheus-community/kube-prometheus-stack -f prometheus-values.yaml --namespace monitoring --create-namespace
```
after need to use `port-forward` on the `grafana` pod to port `3000` to get access to dashboard
- then expose the service `svc/prometheus-grafana`
default login is `admin/prom-operator`

### Scenario:

We will deploy a pod as we did last time that has access to a local volume with option `DirectoryOrCreate` so that volume is created in whatever node it goes to.
and we will deploy a daemonset that will run pod in all nodes so we don't need affinity anymore on the pod and would use in its container a volume that would be mapped to that `volume` and use a `cronjob` to write to it updating the `nginx` `index.html` file.
After we would use `helm` to deploy prometheus and this time talk about the `values.yaml` override/patch with our own values.
Then make `grafana` svc exposed to get to our internet browser and show the metrics.
Then put some stress by `exec` in the `nginx` `pod` and cpu/memory would be stressed to see the metrics on `grafana ` change or not?
Then  we would use tear down the pod, add the annotation `prometheus.io/scrape: true` and redeploy the pod and see if now we have access to `pod-level` (mean access to `container-level` metrics) metrics while before we had `node-level` metrics access by default.

(eg. sidecar container to get nginx metrics exposed)
```yaml
...apiversion/kind...
...metadata/labels...
     # cant scrape both container only one here so might need to use Helm deployment of prometheus as it supports `ServiceMonitor`
    annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '9113'
...

    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80

...volume maybe here

       - name: nginx-exporter
          image: 'nginx/nginx-prometheus-exporter:0.10.0'
          args:
            - '-nginx.scrape-uri=http://localhost/nginx_status'
          resources:
            limits:
              memory: 128Mi
              cpu: 500m
          ports:
            - containerPort: 9113
```

### Solution use `Helm` to deploy `Pormetheus` as it support `ServiceMonitor`
- issue: if having more than one `container` running in a `pod` the `prometheus` `annotations` can only get **`metrics` from one `container` only**.
```yaml
     # cant scrape both container only one here so might need to use Helm deployment of prometheus as it supports `ServiceMonitor`
    annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '9113'
        # so have to choose one `container` only here can't scrape both
        # prometheus.io/port: '80'

```

- solution: use `Helm` and those steps
  - create `Pod` without annotations
  - label **MUST** be set, here `my-metrics-app`
  - `containers` must expose port for service created after to be able to map that port
  
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: junko-time-present-reader
  # MSUT set a label
  labels:
    app: junko-time-reader-app
spec:

  containers:
  #############################################################################################
  - image: nginx
    name: shibuya-webpage-info
    volumeMounts:
    - name: shared-volume
      mountPath: "/usr/share/nginx/html"
    resources:
      limits:
        memory: 150Mi
        cpu: 250m
    ports:
    - containerPort: 9114
      name: shibuya-webpage-info-container-metrix

  #############################################################################################
  - name: nginx-exporter
    image: 'nginx/nginx-prometheus-exporter:0.10.0'
    args:
      - '-nginx.scrape-uri=http://localhost/nginx_status'
    resources:
      limits:
        memory: 150Mi
        cpu: 300m
    # MUST have por exposed
    ports:
    - containerPort: 9113
      name: nginx-exporter-container-metrix

  #############################################################################################
  # now the 'physical' `volume` on the `node` using `hostPath`
  volumes:
  - name: shared-volume
    hostPath:
    path: "/tmp/junko-timing"
    type: "DirectoryOrCreate"

```

  - create a `Service` that selects the `pod` label
```yaml
apiVersion: v1
kind: Service
metadata:
  name: junko-time-reader-app-service
  labels:
    # label for the Service that would be used by the `ServiceMonitor` next resource created supported by `helm` that would target this service to scrape metrics
    app: junko-time-reader-app-service
spec:
  # selector to target the `pod` label
  selector:
    #  targets pod own label
    app: junko-time-reader-app
  # Target container Ports exposed at pod level
  ports:
  - name: nginx-exporter-container-metrix
    port: 9113
    targetPort: 9113
  - name: shibuya-webpage-info-container-metrix
    port: 9114
    targetPort: 9114
```

  - create a `ServiceMonitor` that would scrape that service relayed `containers` ports
    - the `labels.release` must match the name you have chosen when doing your `helm install..` command
    - `selector` must target `service` exposing `pod` `containers` `ports`
    - and `endpoints` `port` names must match the name references in the `service` targeted `port` `name`
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: junko-time-reader-app-servicemonitor
  labels:
    # MUST match your Prometheus Helm release label: so when using command `helm install <name_given>` should be same as `name_given`
    release: <tokyo-mangakissa-monitoring>
spec:
  # selector that is targetting the service where `pod` `containers` `port` are relayed and here it get those by service port name for each of those.
  selector:
    matchLabels:
      # targets service own label
      app: junko-time-reader-app-service
  # matched the port names in the service target
  endpoints:
  - port: nginx-exporter-container-metrix
    interval: 60s
  - port: shibuya-webpage-info-container-metrix
    interval: 60s
```

- so workflow is : `servicemonitor target sevrice label and port names described in service` > `service target label pod and name exposed ports with mapping to those` > `pod container ports exposed`

- then in our scenario we are going to create a `daemonset` that will write to that volume in a period manner using `sleep...`
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: junko-time-tracker-daemon
  namespace: kube-system
  labels:
    k8s-app: junko-tracker-daemon
spec:
  selector:
    matchLabels:
      name: junko-time-tracker-daemon
  template:
    metadata:
      labels:
        name: junko-time-tracker-daemon
    spec:
      # high priority class for preemption advantage on other pods
      priorityClassName: tokyo-junko-time-tracker-priorityclass
      containers:
        - name: junko-time-tracker
          image: busybox:1.36.1
          # we are writing here a command to an `index.html` page which will be written in the `shared-volume` folder
          command:
          - /bin/sh
          - -c
          - while true; do echo "<h1 style='display:flex;felx-direction:row;align-items:center;justify-content:center;color:green;'>Junko will be at Hachiko on the $(date | awk '{print $2,$3}') at exactly $(date | awk '{print $4}')</h1>" > "/tmp/junko-timing/index.html"; sleep 10; done
          resources:
            requests:
              memory: 100Mi
              cpu: 100m
            limits:
              memory: 250Mi
              cpu: 250m
          # now we are going to create the `volumeMount` at same location as the `nginx` other pods one's
          volumeMounts:
          - name: shared-volume
            mountPath: "/tmp/junko-timing"

      terminationGracePeriodSeconds: 15

      volumes:
      - name: shared-volume
        hostPath:
          path: /tmp/junko-timing
          type: "DirectoryOrCreate"
```
(some priority classes)
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: medium-powered-priorityclass
preemptionPolicy: Never
# from `-2147483648` to `1000000000` 
value: 100000
globalDefault: false
description: "This priority class is for medium priority pods only, don't use frequently, just for ones for maintenance to be above the normal pods one"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tokyo-junko-time-tracker-priorityclass
# preemptionPolicy: Never
# from `-2147483648` to `1000000000` 
value: 500000
globalDefault: false
description: "This priority class is very high priority one, use it only for the Junko Tracker."
```

## diagram (if not available check folder concerned by this topic)
(diagram daemonset-helm-prometheus)[https://excalidraw.com/#json=yG9lhk_ypG5Imszd2YRMQ,xDWJVf7bkaQr_Pl64nw0RA]
