!#/bin/sh

sudo apt update && sudo apt install -y curl apt-transport-https

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update -y

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo cat /etc/modules-load.d/containerd.conf

sudo modprobe overlay
sudo modprobe br_netfilter

sudo cat /etc/sysctl.d/kubernetes.conf

sudo sysctl --system

kubeadm version
kubectl version
kubelet --version
containerd --version

sudo apt-cache madison kubeadm
sudo apt-cache madison kubelet
sudo apt-cache madison kubectl

sudo apt-mark unhold kubeadm kubectl kubelet
sudo apt install kubeadm=1.28.15-1.1 kubectl=1.28.15-1.1 kubelet=1.28.15-1.1 -y
sudo apt update

containerd --version

sudo apt install containerd.io=1.7.25-1

containerd --version
kubelet --version
kubectl version
kubeadm version


sudo kubeadm upgrade node

sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart kubelet containerd
sudo systemctl status kubelet containerd
