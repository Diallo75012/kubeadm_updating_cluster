#!/bin/sh

## 1. Cordon Node to Separa
kubectl cordon <controller-node-name OR worker-node-name>

## 2. Drain Node: Make Node Unschedulable To prepare For Maintenance
kubectl drain <node-to-drain> --ignore-daemonsets --delete-emptydir-data

## 3. Upgrade Kubeadm to next minor version 1.27 -> 1.28
#  - make sure you have the repo in `apt` if not install it:
sudo apt update && sudo apt install -y curl apt-transport-https
# get the keys
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
# add kubernetes repo
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

# check the versions
kubeadm version
kubectl version
kubelet --version
containerd --version

# then run next command with the right version:
sudo apt install -y kubeadm=1.28.10-00

# get rid of deprecated kubernetes repo list
sudo rm /etc/apt/sources.list.d/kubernetes.list

# disable swap
# on all nodes disable swap and add kernel settings
sudo apt update
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

# unhold version to be able to upgrade those and then hold back those versions
sudo apt-mark unhold kubeadm kubelet kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubeadm=1.28.15-1.1 kubelet=1.28.15-1.1 kebectl=1.28.15-1.1 && \
sudo apt-mark hold kubeadm kubelet kubectl

## . Install Compatible Version of Containerd (Optional but better have it updated even if it is Ok for few years...)
sudo apt-get install -y containerd.io=<required-version>
sudo apt install containerd.io=1.7.25-1
sudo systemctl restart containerd

## 4. Verify Upgrade Plan and Ugrade (Only in the first Control Plane: other ones are going to pick it up)
# This is for the first control plane node only
# if having only one control node need to uncordon it  and restart kubelet and containerd
# to have the node `Ready` otherwise you won't be able to upgrade
kubectl uncorn controller.creditizens.net
sudo systemctl restart kubelet containerd
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.28.x

## 4'. Upgrade Other Control Planes (Optional if more than one control plane)
# This is after having ugraded the first control plane and the other ones don't use `apply` but use `upgrade node` instead
# Also no need to `uprgade plan` in those controller nodes.
sudo kubeadm upgrade node

## . Restart Kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

## . Bring Node Back Online
kubectl uncordon <node-to-uncordon>

## . Optionally Check that critical add-ons (CoreDNS, kube-proxy) are running the updated versions
kubectl get daemonset kube-proxy -n kube-system -o=jsonpath='{.spec.template.spec.containers[0].image}'


