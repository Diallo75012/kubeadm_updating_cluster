# cNext
- [ ] update the cluster versions until we reach 1.32 (we are at 1.27)
    so we will have to do same process several times and fix any compatibility issues along the way.
    need to check supported versions ranges for each kubeadm updated version


# Take Snapshot of ETCD (for Safety)

## 1. Get the etcd Pod Name
```bash
kubectl get pods -n kube-system | grep etcd
Outputs:
etcd-controller-01   1/1   Running   0   1d
```

## 2. Create a Snapshot of etcd
```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /var/lib/etcd/etcd-snapshot-$(date +%F-%T).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```
This saves a snapshot with a timestamped filename in /var/lib/etcd/.
You can change the path if needed.

## 3. Verify the Snapshot Integrity
```bash
sudo ETCDCTL_API=3 etcdctl snapshot status /var/lib/etcd/etcd-snapshot-YYYY-MM-DD-HH-MM-SS.db
```

## 4. Etra: Restoring etcd from Snapshot (if Needed)
```bash
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/etcd/etcd-snapshot-YYYY-MM-DD-HH-MM-SS.db \
  --data-dir /var/lib/etcd-new
```
**Then, update the etcd manifest in `/etc/kubernetes/manifests/etcd.yaml` to point to `/var/lib/etcd-new`, and restart the control plane.**

# Uprgade Cluster:
- **[source: Kubernetes Documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#:~:text=During%20upgrade%20kubeadm%20writes%20the,etc%2Fkubernetes%2Ftmp)**
###  **Rules:**
- kubeadm cluster updates cn be done onl one minor version at a time 1.27 -> 1.28 -> 1.29...
- kubelet and containerd versions cn e max 3 versions older see documentation to see their corresponding versions but it is recommended to have those not more than on version older
- Need to do controller nodes first one at a time
- Need to to do the worker nodes one at a time
- Need for sure to know the architecture of taints/toleration/resource limits to make sure for seamless workload move to other nodes.
- Need also to see upgrades matching of Calico (but used the latest available the free one)
- Need to Backup etcd even if kubeadm doesn it automaicall placing backups to `/etc/kubernetes/tmp`
- Need to make sure version are `unhold` then upgrade and `hold` thse back for verions to not upgrade and have full control on stable cluster state 


**Important:** For `1` to `3` you can do the upgrade and then cordon and drain or the otherway around 
    as new state application to the cluster is done only with the command of `4` of `4'`

## 1. Cordon Node to Separa 
```bash
kubectl cordon <controller-node-name OR worker-node-name>
```

## 2. Drain Node: Make Node Unschedulable To prepare For Maintenance
```bash
kubectl drain <node-to-drain> --ignore-daemonsets --delete-emptydir-data
```

## 3. Upgrade Kubeadm to next minor version 1.27 -> 1.28
- make sure you have the repo in `apt` if not install it:
```bash
sudo apt update && sudo apt install -y curl apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
# check the versions
kubeadm version
kubectl version
kubelet --version
containerd --version
# then run next command with the right version:
`sudo apt install -y kubeadm=1.28.10-00`
```
# get rid of deprecated kubernetes repo list
sudo rm /etc/apt/sources.list.d/kubernetes.list

# disable swap
sudo apt update
sudo apt install -y curl apt-transport-https
# get the signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
# add kubernetes apt repo
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# update package list
sudo apt update

# on all nodes disable swap and add kernel settings
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# set up some kernel configs
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# load necessary kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
Outputs:
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1


# reload changes
sudo sysctl --system
# check versions available to do the update for kubeadm kubelet and kubectl
sudo apt-cache madison kubeadm
sudo apt-cache madison kubelet
sudo apt-cache madison kubectl
```bash
sudo apt-mark unhold kubeadm kubelet kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubeadm=1.28.15-1.1 kubelet=1.28.15-1.1 kebectl=1.28.15-1.1 && \
sudo apt-mark hold kubeadm kubelet kubectl
```

## . Install Compatible Version of Containerd (Optional but better have it updated even if it is Ok for few years...)
```bash
sudo apt-get install -y containerd.io=<required-version>
sudo apt install containerd.io=1.7.25-1
sudo systemctl restart containerd
```

## 4. Verify Upgrade Plan and Ugrade (Only in the first Control Plane: other ones are going to pick it up)
This is for the first control plane node only
```bash
# if having only one control node need to uncordon it  and restart kubelet and containerd
# to have the node `Ready` otherwise you won't be able to upgrade
kubectl uncorn controller.creditizens.net
sudo systemctl restart kubelet containerd
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.28.x
```

## 4'. Upgrade Other Control Planes (Optional if more than one control plane)
This is after having ugraded the first control plane and the other ones don't use `apply` but use `upgrade node` instead
Also no need to `uprgade plan` in those controller nodes.
```bash
sudo kubeadm upgrade node
```



## . Restart Kubelet
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## . Bring Node Back Online
```bash
kubectl uncordon <node-to-uncordon>
```

## . Optionally Check that critical add-ons (CoreDNS, kube-proxy) are running the updated versions
```bash
kubectl get daemonset kube-proxy -n kube-system -o=jsonpath='{.spec.template.spec.containers[0].image}'


_________________________________________________

For worker nodes
- on controller node
kubectl cordon <controller-node-name OR worker-node-name>
```## 2. Drain Node: Make Node Unschedulable To prepare For Maintenance
```bash
kubectl drain <node-to-drain> --ignore-daemonsets --delete-emptydir-data

- on worker node
sudo apt update && sudo apt install -y curl apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update -y


# on all nodes disable swap and add kernel settings
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# set up some kernel configs
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# load necessary kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
Outputs:
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1

sudo sysctl --system

kubeadm version
kubectl version
kubelet --version
containerd --version

# just check if version is there otherwise error with signing key or repo in `/etc/source.list.d/kubernetes.list`
sudo apt-cache madison kubeadm
sudo apt-cache madison kubelet
sudo apt-cache madison kubectl

sudo apt-mark unhold kubeadm kubectl kubelet
sudo apt install kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1 kubelet=1.28.15-1.1 -y
sudo apt update

containerd --version

# optional trick to get the terminal show you the true version to get but from `containerd.io=<version>`
sudo apt install containerd=1.7
Outputs:
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Package containerd is a virtual package provided by:
  containerd.io 1.7.25-1
You should explicitly select one to install.

# othersize just install it direcly, this is done having checked the version matching at: [containerd.io doc](https://containerd.io/releases/#:~:text=Kubernetes%20Version%20containerd%20Version%20CRI,36%2Bv1)
sudo apt install containerd.io=1.7.25-1

containerd --version
kubelet --version
Kubernetes v1.28.15
kubectl version
kubeadm version

# perform the upgrade
kubeadm upgrade node

sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart kubelet containerd
sudo systemctl status kubelet containerd
```

## . Restart Kubelet
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet


- on controller node
```bash
kubectl uncordon <node-to-uncordon>
```
