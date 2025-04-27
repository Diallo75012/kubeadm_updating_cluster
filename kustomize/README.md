# `Kustomize` (projects, configs and resources manager like `Helm`)
source: (Documentation Kubernetes Kustomzie)[https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/]
Like `Helm` it permits to manage the deployment to the cluster of resources in an organized manner.
So that you can put and organize files in different directories and deploy it as a stack or based on options you will get a set of those deployed.
It comes with the istallation of `kubectl` used as a command: 
```bash
# this to see the resources that will be deployed by `kustomize`
kubectl Kustomize kustomization.yaml
# this to apply those resources to the cluster using the option `-k`
kubectl apply -k <kustomization_directory>
```

- install binary otherwise `kustomize`
But it can be also installed as a binary: source (documentation `kustomize` binary)[https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/] which helps to use `kustomize buiild <path>` command 
```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
```

Inside the `kustomization.yaml` file you get the logic of which folder resources are to be deployed and so on.

**Powerfull as you could have a git repository and organize your project in different `kustomize` directories and be able to pull it directly and apply to cluster:`kubectl kustomize https://github/<repo_folder...>` **
**The name `kustomize` is important because that what the command is looking for to locate the project**
```bash
# eg. showing that it searches for certain file
 k kustomize
error: unable to find one of 'kustomization.yaml', 'kustomization.yml' or 'Kustomization' in directory '/home/creditizens/kubeadm_updating_cluster/kustomize'
```

- Part of the options we have one that make `Kustomize` have ability to create an `Helm` chart:
```bash
# from `kubectl kustomize -h`: need to set this to `true` in order to activate the `helmCharts` generator
# as it pull from external repo it is by default deactivated for security reasons
--enable-helm=false: Enable use of the Helm chart inflator generator.
# found another to use `helm` that this time you have installed in your computer and would use normal `helm` command
# so at this time it is interesting as you will have access to `releases rollback`
--helm-command='helm': helm command (path to executable)
```

### example `kustomization.yaml` that uses a remote repo
# kustomization.yaml (local one)
```
...
resources:
  - github.com/my-org/my-k8s-manifests//base?ref=v1.0.0
...
```
Explanation:
- `github.com/my-org/my-k8s-manifests` is the remote repo.
- `//base` is the subdirectory in that repo containing a kustomization.yaml.
- `?ref=v1.0.0` pins the version/commit/tag/branch.

Then run `kubectl apply -k .`

### some `kustomize` commands
```bash
# view what is your folder haveing the `kustomization.yaml` file will create in therm of resources: Good to check if everything look fine
kubectl kustomize ./
# apply to cluster
kubectl apply -k ./
kustomize build .  # if having installed the binary `https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/`
# view the deployment
kubectl get -k ./
kubectl describe -k ./
# check the state of the change in state of the cluster if the manifest would have been applied to it
kubectl diff -k ./
# delete the deployment
kubectl delete -k ./
```

## Generators
`Kustomization.yaml` file need to be created and there are some `Generators` of different `kubernetes` resources.
So how does it works:
- you create this `kustomization.yaml` file and have a specific `generator` like `configfMapGenerator` for example which will create a `kubernetes` `configMap`
  Then you can have otpion keywords to get values or key/values from `literals` that you declare in the file directly or `files` which will be referenced or `envs` for `.env` files
  We will use an eg. here but see documentation for other kind of resources and how to do those but this example will show how it is formatted in general
```bash
# Create an application.properties file
nano yoyogi.properties
park-entry=harajuku
```
```bash
# create a secrets.yaml file
nano .env
shibuya=isogashii
tsutaya=busy
```
```bash
# create a deployment
nano deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app
        volumeMounts:
        - name: config
          mountPath: /config
        - name: mysecret-volume
          readOnly: true
          mountPath: "/django-project/my-secret-volume"

      volumes:
      - name: config
        configMap:
          name: yoyogi-data
      - name: mysecret-volume
        secret:
          secretName: shibuya-secret
```
```bash
# create the `kustomization.yaml` file that will create the configmap and the secret
nano kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
configMapGenerator:
- name: yoyogi-data
  files:
  - yoyogi.properties
- name: yoyogi-data2
  literals:
  - MANGAKISSA=lv5
secretGenerator:
- name: shibuya-secret
  envs:
  - .env
  # add this if you don't want the automatic `suffix` append for consistency
  # otherwise it will also change it and append in the yaml file volume so will work fine if you leave the `suffix` (your chocice)
  # type: Opaque
  # options:
    # disableNameSuffixHash: true
  # file:
  # - <file_path>.txt
```
```bash
# so here you will see in the output that the generated deployment will have to `configMap` and `secret` a `suffix` appended to the name of those
kubectl kustomize ./
```

- example of `configMap`  created by `configMapGenerator` of `kustomize`
```yaml
apiVersion: v1
data:
  # if using option `files` will have the file name used like eg. (here of `yoyogi.proprieties` having the key/value data):
  # yoyogi2.properties: |
  # otherwise there will be just the key/value same like in our example above
    MANGAKISSA=lv5    
kind: ConfigMap
metadata:
  # suffix added by default by `kustomize` so that when you change the data the name will be different with another suffixe
  # can use option `disableNameSuffixHash: true` to not get any suffix written by `kustomize`
  name: yoyogi-data2-8mbdf7882g
```

## Generators Options `generatorOptions`
```yaml
# `kustomization.yaml`
...
generatorOptions:
  # activate or desactivate the automatic `suffix` hash added by `kustomize`
  disableNameSuffixHash: true
  # have all `labels` and `annotations`
  labels:
    type: generated
  annotations:
    note: generated
...
```
eg:
```yaml
kustomization.yaml
# set same namespace in all 
namespace: my-namespace
# set same prefix in all
namePrefix: dev-
# set same suffix in all
nameSuffix: "-001"
# set same label in all
# or maybe use `commonLabels`
labels:
  - pairs:
      app: bingo
    # with selectors as `deployments` have internal `selector` selecting the `template` `label` part
    includeSelectors: true
# use same `annotiations` in all
commonAnnotations:
  oncallPager: 800-555-1212
# target resoruce
resources:
- deployment.yaml
```

## organization of `compostions` of resources folders
so here we will again use the `kustomization.yaml` file to set those resources links.
We will use the field `resources`, indicating the path of those resources

### we can also in this `compositions` patch resources using `patches`
`patches` can use some field to target resources to be patched:
  - `group`, `version`, `kind`, `name`, `namespace`, `labelSelector` and `annotationSelector`
`patches` different mechanisms that can be choosed from:
  - `StrategicMerge` and `Json6902`

Recommanded to patch one stuff at a time so make small patches.

eg: you have created two different small `yaml` files where the resource is named, label and other but have changed a value, for just one little patch.
you give it a custom name to say what you are patching and then use a `kustomize` file to apply those patches. here we show just the `kustomize` file
(`kustomization.yaml`: `StrategicMerge` way)
```yaml
resources:
- deployment.yaml
patches:
  - path: increase_replicas.yaml
  - path: set_memory.yaml
```

(`kustomization.yaml`: for arbitrary fields, it can't be patched using `StrategicMerge` so use the `Json6902` way)
```yaml
resources:
- deployment.yaml

patches:
- target:
    # matches on different fields example
    group: apps
    version: v1
    kind: Deployment
    name: my-nginx
  path: my_custom_field_patch.yaml
```

- another example of patching way
(`deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
spec:
  selector:
    matchLabels:
      run: my-nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
```

(`kustomization.yaml`)
```yaml
resources:
- deployment.yaml
images:
- name: nginx
  newName: my.image.registry/nginx
  newTag: 1.4.0
```

## Extra field to use other resource name (in this example) for specific fields
(`kustomization.yaml`: so here the `source` resource `Service` name from `metadata.name` is used
to name the container of the deployment `targets`: `spec.template.spec.containers.0.command.2`)
```yaml
...
replacements:
- source:
    kind: Service
    name: my-nginx
    fieldPath: metadata.name
  targets:
  - select:
      kind: Deployment
      name: my-nginx
    fieldPaths:
    - spec.template.spec.containers.0.command.2
...
```

## bases and overlays
This is probably the most interesting part as this is why I am interested in `kustomize` as we can organize the folders in one upper (or more for needs of other resource `compositions`) `overlay` and some underlying `bases` referenced in the `overlay`.
- `bases`: can be `any path` or `repository` having some `yaml` files of a stack and **very important** a `kustomization.yaml` file.
- `overlays`: you can use different overlays folders that reference different bases to make your `compositon` and for example use `namePrefix: naha-` to have all those resources having same prefix location (like we use to do in our examples of Japanese locations). **very important** `overlays` have a `kustomization.yaml` file that references those bases.

```bash
- overlays/
  - kustomization.yaml: and here inside in `resources` have `ingress.yaml` and `../bases1` folder or even remote repo `https://github.com/tokyo-repo/locations/naha-base/`
  - ingress.yaml
- base1/
  - kustomization.yaml: and here reference in `resources`: `deplyment.yaml` and `service.yaml` and put your `kustomize` other options if needed
  - deployment.yaml
  - service.yaml

```

- remote repo that is referenced in local `overlays`
```markdown
.
├── overlays/
│   └── dev/
│       ├── kustomization.yaml
│       └── deployment-patch.yaml
```
(`overlays/dev/kustomization.yaml`: local)
```yaml
...
resources:
  - github.com/my-org/my-k8s-manifests//base?ref=v1.0.0

patchesStrategicMerge:
  - deployment-patch.yaml

configMapGenerator:
  - name: app-config
    literals:
      - ENV=dev
...
```

then run `kubectl apply -k overlays/dev`


## `Helm` + `Kustomize`
- `Helm` for packaging
- `Kustomize` for customization without forking the chart

Example: we want to install `Prometheus` `Helm` chart but patch a few things (resources, annotations, node selectors, etc) without modifying the original chart = we use `Kustomize`

`Kustomize` has a special plugin called `helmCharts`. so when we apply to the cluster using `kustomise`
- Downloads the chart if needed.
- Runs helm template locally (generating the raw YAML).
- Then applies your Kustomize patches (overlay).

### Example scenario for `helm` `prometheus` stack and using custom `values.yaml` file

- create dir
```bash
mkdir -p monitoring
cd monitoring
```

- `kustomization.yaml`
**order is important** as here if the `resources` is placed under the `helmCharts` , it will throw an error as the `namespace` referenced in `helmCharts` does not exist yet. so we put the resources first that need to be applies to the cluster so the `namespace` will be created and then the `helmChart` will find it and be released
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# resource deployed by `kustomize` to create the namespace
resources:
- namespace.yaml

# `helmCharts` option to apply to the cluster `prometheus` `helm` chart with custom `values.yaml` file
helmCharts:
- name: kube-prometheus-stack
  releaseName: prometheus
  namespace: shibuya-monitoring
  repo: https://prometheus-community.github.io/helm-charts
  version: 55.5.0
  # here the path of our `custom_values.yaml`
  valuesFile: custom_values.yaml
  includeCRDs: true
```

- `namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shibuya-monitoring
```

- `custom_value.yaml` to limt resources use of stack deployment `prometheus` and its `nodeExporter`
```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: "200Mi"
        cpu: "50m"
      limits:
        memory: "500Mi"
        cpu: "250m"

nodeExporter:
  resources:
    requests:
      memory: "100Mi"
      cpu: "50m"
    limits:
      memory: "200Mi"
      cpu: "100m"
```


- apply to cluster with mandatory option `--enable-helm`
**important note about option `--enable-helm`**: Plugins like helmCharts are disabled by default for security reasons (they pull remote resources). So you explicitly need to allow it with --enable-helm

```bash
# to see resources yaml files
kubectl kustomize . --enable-helm
# need to install the kustomize binary to be able to `build`
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
# then build with the option `--enable-helm` set to true
kustomize build . --enable-helm=true > helm_kustomize_deploy_prep.yaml
# to apply to cluster
kubectl apply -f helm_kustomize_deploy_prep.yaml
```

kustomize → pulls the chart → applies helm template → injects values.yaml → modifies with Kustomize → applies.

Amazing because:
- No need to pre-download the Helm chart manually.
- No need a HelmRelease controller (like FluxCD) — it's pure kubectl apply -k.
- No need to install Helm separately on your system, just Kustomize (>=v4.1.0).

**Important Note about Release Rollback**
NO HELM RELEASE possibility, this is the limitation of `kustomize-helm`, therefore, NO ROLLBACK
just pulls repo and apply directly manifest to cluster with all defined in `helm chart`
**NO `helm rollback`, nor `helm upgrade`**
But might be possible to use `helm` binary that you have installed and at this time it would be available (`rollback`/`release`)
with this option to `k kustomize ` `--helm-command='helm'`: helm command (path to executable)

## scenario
- `kustomize` for one resource applied to cluster
- `kustomize` with some options (prefix for example) but using overlay/base
- `kustomize` +  `helm` example of `Prometheus` and advantage that we don't need to install `helm`.
  But finally decided to make an easy example as `helm` loses all it advantage when used with `kustomize` but can make a pod simple one an dput in the templates, deploy it using helm and then use kustomize to `kustomize` it using the option `helmCharts` so that i can show how to install `kustomize` binary and deploy that patch. just playing but `helm` by itself does it well.
so we will for ksutomize+helm use helm and show it goes fine with our chart and the html page, then we create the charts/ folder and copy the chart used with helm in the charts/ folder and create a custom values.yaml file and create a yaml file to create our namespace and then we create the kustomization.yaml file that would that all of those into consideration to create the namespace and to update the other values so that we can show that the nodeport has changed and the message also has changed. show how to do it with `kustomize build` and with `kubectl apply -k`

## issues with `kustomize + helm`
- issue with `helmCharts` option of `kustomization.yaml` that is very limited in what can be done. so throws error as can't find the `helm` chart.
- **solution**: learned that we need to create a `charts/` folder and put our chart folder insde and we need to use the option `--enable-helm`
                can add option `--load-restrictor=LoadRestrictionsNone`
                if having your `charts` folder outside not in same folder as your `kustomization.yaml` file
                but better not do that as it overcomplicate it, `kustomize` is limited
- issue: no `rollback` possible or `--create-namespace`, so forget of the power of `helm`
- **solution**: just use `helm` for `helm` it is more powerful than `kustomize` anyway.
