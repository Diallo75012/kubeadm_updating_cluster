# Kubernetes Plugins 

External utilities can be installed and used to interact with Kubernetes.
The easiest way to manage those is by installing `Krew` which will be used in combinaison of `kubectl`.

### install `krew`
source: [Krew Install](https://krew.sigs.k8s.io/docs/user-guide/setup/install/)
1. Install using this command (do not omit the parenthesis):
```bash
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
```
2. add to `~/.bashrc` the export to add it to `PATH`:
```bash
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
source ~/.bashrc
```
3. we can now use `krew` with `kubectl` to install plugins
```bash
# here plugin that will display the yaml/josn in a `neat` clean way when for example extracting those from cluster
kubectl krew install neat
```
4. now use the plugin to get here nice `yaml` or `json` output of resources
```bash
kubectl get deployment nginx -n nginx -o yaml | kubectl neat > nginx-deployment.yaml
```
- outputs:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "3"
  labels:
    app: nginx
  name: nginx
  namespace: nginx
spec:
  progressDeadlineSeconds: 600
  replicas: 3
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
```
