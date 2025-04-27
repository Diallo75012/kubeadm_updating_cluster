# KUBEADM TUTORIAL
Using abstracted away example of `Tokyo` neighbourg and places to explain some `Kubernetes` concepts with notes along the way.
- tried to keep it raw, close to hands-on
- each topic have the huge `noted.md` file part related to it in a  `README.md`
- you still need the (kubernetes doc)[https://kubernetes.io] next to you and `ChatGPT` for high level explanation. For Kubernetes do not rely on `ChatGPT` it has made lots of errors. the small bits it forgets are important and will make all fail and you will have headacke. so use this last `human` way of learning `kubernetes` repo. 

**Nothing Better Than Hand-On Practice**
**Enjoyuuuuu**

# KUBEADM OLD CLUSTER UPDATE
- Started the update:
- [x] get kubelet certificated renewed on controller node, worker node and get it running again without reseting the cluster
- [x] update the versions until latest version of kubeadm (for the moment at v1.27.3) so many updates to do (cordon, unhold update, update, cordon). but might create another repo for that to do it in `Rust`, have done update from `1.27` to `1.29.15`, latest is `1.32` so will use Rust until nice upgrade smood in other repor dedicated to that
- [x] use the cluster to perform some tutorials while updating and after update. all Done
  - [] devide node part in README.md in each topic folders
