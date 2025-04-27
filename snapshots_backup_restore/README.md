# Backup & Restore
source: (kubernetes doc on etcd backup and restore)[https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/]
- **Little resume:**
When we talk about backup and restore is all about ETCD. 
We need to go inside the pod which is present in the namespace `kube-system`.
Then do the work of creating snapshots but it stays inside the pod. Which is actually sharing same path with the underlying node filesystem.
Therefore, can be accessed at `/var/lib/etcd/` which has been defined as volume in `/etc/kubernetes/manifests/etcd.yaml`.

**Why no StorageClass, PVC and PV?**
Because:
- Needs to start before Kubernetes APIs and controllers are even online
- Must not depend on the Kubernetes scheduler or provisioners
- Is managed as a static pod (host-managed, not API-managed)

So here we can see that `etcd` is not using the same process and not passing by the API server.

- ckech `etcd` version
```yaml
kubectl exec -n kube-system etcd-controller.creditizens.net -- etcdctl version
etcdctl version: 3.5.15
API version: 3.5
```

## ETCD Backup

- go inside the `etcd pod` and make a snapshot. No matter how many controller in the cluster all `etcd` present in each `controller` nodes would be saved
  in that snapshot.
  So here in the node file path the backup snapshot would be in the folder `/var/lib/etcd/`.

**Command running it from the node terminal, running it inside the `etcd` pod**
```yaml
kubectl exec -n kube-system etcd-<your-controller-node-name> -- \
  etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
          --cert=/etc/kubernetes/pki/etcd/server.crt \
          --key=/etc/kubernetes/pki/etcd/server.key \
          snapshot save /var/lib/etcd/backup.db
```

**Command running it from the node terminal, outside this time of the `etcd` pod so just terminal to snapshop directly**
Here `ETCDCTL_API=3` is telling which version of `etcd` API we are running on the cluster (here since vercion etcd 3.5)
need to install the binary `etcdctl` so have it available to run the command:
```bash
# get your version of `etcd` or check online which `etcd` version matches your `kubernetes` version: https://kubernetes.io/releases/version-skew-policy/#etcd
kubectl exec -n kube-system etcd-controller.creditizens.net -- etcdctl version
etcdctl version: 3.5.15
API version: 3.5
# then use that version number to get the release, if not available go to their `github and check versions available in the releases`: https://github.com/etcd-io/etcd/releases
curl -LO https://github.com/etcd-io/etcd/releases/download/v3.5.15/etcd-v3.5.15-linux-amd64.tar.gz
tar -xzvf etcd-v3.5.15-linux-amd64.tar.gz
sudo mv etcd-v3.5.15-linux-amd64/etcdctl /usr/local/bin/
```
```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup.db
```
- accessory command if can't ssh to one of the controller nodes using `kubectl cp` command to copy the snapshot to another node file system path.
```yaml
# Copy from pod to controller node
kubectl cp kube-system/etcd-<your-node-name>:/var/lib/etcd/backup.db ./backup.db
```

- can inspect the metadata of the backup
The backup is not human readable as it is a binary file (type LevelDB)
```bash
ETCDCTL_API=3 etcdctl snapshot status backup.db
```

- Options to encrypt the `etcd` snapshot
It can't be encrypted but ....
  - can encrypt the data saved to it at rest meaning inside the cluster when saving to `etcd` all would be saved but in an encrypted form
    Kuberneted permits to save at rest using an encryption file: `/etc/kubernetes/encryption-config.yaml`
    Used for encrypting Secrets, ConfigMaps, etc., before writing to etcd.
  - encrypt after having made the snapshot using: 
    - `OpenSSL`:
      ```bash
      # encrypt
      openssl enc -aes-256-cbc -salt -in backup.db -out backup.db.enc
      # decrypt
      openssl enc -d -aes-256-cbc -in backup.db.enc -out backup.db
      ```
    - `GPG`:
      ```bash
      # encrypt
      gpg -c backup.db
      # decrypt:
      ```bash
      gpg -d backup.db.gpg > backup.db
      ```
    - `s3` or `Vault`:
      so here moving the snapshot to s3 and enabling AES or KMS encryption
      or using Hashicorp Vault and saving it there.

`OR`
use `etcdutl`:
(it is installed with the binary when you install the `etcdctl` binary)
- Encrypt snapshot: The encryption key must be a symmetric key (usually 32 chars)
```bash
etcdutl snapshot encrypt --input backup.db --output backup.encrypted.db --key myencryptionkey_very_long_string
```
- Decrypt snapshot (key must be a symmetric key (usually 32 chars))
```bash
etcdutl snapshot decrypt --input backup.encrypted.db --output backup.db --key myencryptionkey_very_long_string
```
- Inspect metadata
```bash
etcdutl snapshot status backup.db
```

### Can we get a snapshot and use it in a completely new cluster different from the one where the snapshot has been made?
Yes but... Headacke as, all thsoe components must match:
- Kubernetes version: strongly recommended
- etcd version: Match snapshot format
- Cluster name: Specified in kubeadm config
- API Server certs (SANs): Needed for consistent identity
- CNI plugin (e.g., Calico, Cilium): Recommended Some network state is in etcd


### What won’t be restored from the snapshot?
- Kubelet certificates
- Kubeconfig files
- Filesystem volumes
- Kubeadm configuration (stored outside etcd)


# Restore
**Important Node:** 
Restoration of `etcd` will create downtime in the cluster as the `controller` is not working if `etcd` is not there. 
But this will afftect only `controller` nodes, the `worker` ndoes and their workload wouldn't be affected.
So pods would still run normally and `calico` as well and networking as well as `ingress`.
Just can't :
  - use any `kubectl` commands
  - `kubeadm` commands
  - schedule new pods
  - `HPA` (autoscaling), `Jobs` as relying on `APIserver` wont works
so still a risk of issues with pods failing. but it is fine.i


- make sure that the APIserver is not running and that the `volumes`, `hostpath` and `--data-dir` folders match where the snapshot is
  so here can mv all the manifest like `/etc/kubernetes/manifests/etcd.yaml` to another folder to restart the api server or just change one config in it and it will restart, then bring it back to the `/etc/kubernetes/manifests/` folder or change the config that you have changed before back to it normal state.
  all this are tricks to restart APIserver
- stop `kubelet` service
- **Note:** The documentation is suggesting that some features of `etcdctl` might become deprecated like the one to check `status` which will be deprecated
  so just change commands by replacing `etcdctl` by `etcdutl` for `status` check and for restoration of `.db` files.
  eg.:`etcdutl --write-out=table snapshot status snapshot.db `
```bash
etcdutl --data-dir <data-dir-location> snapshot restore snapshot.db
```
so here `--data-dir` will be the directory that will be created during the restore process (from doc info)
if no validation `hash` present as snapshot created from a specific directory different from the `snapshot save` one, can run the command with option `--skip-hash-check` has normal `snapshot restore` only would check for integrity using that `hash` but sometimes it is not present (like for restore to new cluster for example). See doc of `etcd` for that: (doc etcd)[https://etcd.io/docs/v3.6/op-guide/recovery/#restoring-a-cluster]
(eg. with more options:`etcdutl snapshot restore snapshot.db --bump-revision 1000000000 --mark-compacted --data-dir output-dir`)
- restarts APIserver

**Important:**
The folder `/var/lib/etcd/` is having a `member` folder and that is where `etcd` is having it's logs (transaction history) in the form of `.wal` files and their conterpart `.snap` files which is `etcd`'s internal snapshot and where the `.db` file is the actual `snapshot` like your `backup.db`.
But, when we restore, we need to delete everything from the `var/lib/etcd/` folder to not get an error like `member` already exist. so get rid of the full `member` folder or back it up.
Your snapshot can live anywhere in the file system (AWS S3 as well as Hashicorp Vault) but the `--data-dir` should be same as in the `/etc/kubernetes/manifests/etcd.yaml` file so here `/avr/lib/etcd/` where a new member will be created when restoring.
so let's review the command:
```bash
sudo etcdutl snapshot restore /my/custom/path/location/my_backup.db --data-dir /var/lib/etcd 
```

### Full restore example
- prerequisite: have `etcdctl` or `etcdutl` installed
- your `backup.db` binary file somewhere in your `Filesystem`, `Hashicorp Vault` or `AWS s3`
- `/etc/kubernetes/manifests/etcd.yaml` file present


.1 Stop Kubelet
# stop kubelet because otherwise it will keep runnign and recreate the `member` folder that we want to get rid of to create a new one on snapshot restoration 
```bash
sudo systemctl stop kubelet
```

.2 Stop all component of controller by moving the `.yaml` files from `/etc/kubernetes/manifests/` folder:
`Kubelet` will see that `etcd.yaml` stopped and the `controller` node will stop
```bash
# example with `etcd.yaml` but do it for all other components as well `sheduler`, `apiserver`, `controller manager`
sudo mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests/etcd.yaml.bak
```

.3 Restore
```bash
# or sudo mv /var/lib/etcd/member /var/lib/etcd/BAK_member
sudo rm -rf /var/lib/etcd/*
sudo ETCDCTL_API=3 etcdutl snapshot restore /var/lib/etcd/backup.db --data-dir /var/lib/etcd-restore  --bump-revision=1000000000 --mark-compacted
```
- `/var/lib/etcd/backup.db`: full path to the existing snapshot file
- `--data-dir` `/var/lib/etcd-restore`: folder where etcd will reconstruct the DB.
  The folder you indicate here will be created if it doesn't exist, no need manual creation beforehands.
  But it is not the default folder so need to update `/etc/kubernetes/manifests/etcd.yaml` file `volumes/hostPath, --data-dir`
  Otherwise just use the default folder but delete all from `/var/lib/etcd/` or save it somewhere else. as the restore will create a `member` folder
  and you will get an error saying that `a member already exist`

.4 Update the `etcd.yaml` file's dir path to look at (only if needed)
```bash
sudo nano /etc/kubernetes/manifests/etcd.yaml.back
```
.4' **This is optional, do it just if you want to use another folder for `--data-dir` other than the default one `/var/lib/etcd/`**
Look for the --data-dir flag and change:
```yaml
--data-dir=/var/lib/etcd
```
to:
```yaml
--data-dir=/var/lib/etcd-restore
```
Also update the hostPath volume mount if needed:
```yaml
- name: etcd-data
  hostPath:
    path: /var/lib/etcd-restore
    type: DirectoryOrCreate # this would create the folder automatically by `kubelet` so no need human to go and have it created beforehands, but need to be deleted manually as it offers a way of having a persistent volume as when the pod dies the volume and data stays on the node. so becareful as well to not have node space storage taken by forgotten test volumes or other (bash script for clean up or ansible can be good and use standardisation of which path is used so that that path can be discovered and content wipped up without any issues)
```

.5 now change the backup name back to its original for the `etcd.yaml` and all other `.yaml` files in `/etc/kubernetes/manifests/` that when restarteing kubelet it would pick it up with new config and restart
```bash
sudo mv /etc/kubernetes/manifests/etcd.yaml.back /etc/kubernetes/manifests/etcd.yaml
```

-6 restart kubelet
# restart kubelet
```bash
sudo systemctl restart kubelet
```

-7 Enjoy the cluster with restored backup
```bash
kubectl get pods -n kube-system
```        


## Backup & Restore Scenarios:
- before...
Create an `nginx` deployment with config map that show a message and updates the `index.html` file and use it for each example with a new message.
- 1) where we make backup from going inside the pod and showing where in the `/etc/kubernetes/manifests/etcd.yaml` file we find the volume path.
     say that it is a binary and that it is not encrypted. use `opensssl` way to encrypt it. OR say that there is a more complicated way to do it at `Rest` so store data to `etcd` but encrypt it before storage. Make sure the cluster state have an nginx showing a certain message
```bash
kubectl exec -n kube-system etcd-controller.creditizens.net -- \
  etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
          --cert=/etc/kubernetes/pki/etcd/server.crt \
          --key=/etc/kubernetes/pki/etcd/server.key \
          snapshot save /var/lib/etcd/backup.db
```
- 2) scenario in which we will do backup from outside telling that documentation is suggesting us to use `etcdctl`.
     we install it and make a snapshot from outside the cluster. We also show that we can encrypt it using `etcdctl`.
     make sure thet the state of the cluster has changed and nginx showing another message.
     Note: `etcd` and `etcdutl` binaries would be also installed during the process of installation of `etcdctl`. they are shipped together.
source: (github etcdctl)[https://github.com/etcd-io/etcd/tree/main]
```bash
# installing `etcdctl` will make `etcdutl` available as binary as well
curl -LO https://github.com/etcd-io/etcd/releases/download/v3.5.15/etcd-v3.5.15-linux-amd64.tar.gz
tar xzvf etcd-v3.5.15-linux-amd64.tar.gz
sudo mv etcd-v3.5.15-linux-amd64/etcdctl /usr/local/bin/
```
```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup.db
```
```bash
# encrypt
openssl enc -aes-256-cbc -salt -in backup.db -out backup.db.enc
# decrypt
openssl enc -d -aes-256-cbc -in backup.db.enc -out backup.db
```

- 3) now make restore using one snapshot and the other. so need to decrypt  and then make the snapshot.
     Say that storage for the snapshot could be AWS S3 with encryption AES or KMS. OR use Hashicorp Vault.
```bash
# this would stop kubelet so the cluster workload would be fine but not the controller node anymore as it detects the manifest presence or not
# not `etcd.yaml` would stop the `apiserver` and `kubelet`
sudo mv /etc/kubernetes/manifests/etcd.yaml /root/etcd.yaml.bak  # or just temporarily rename it to stop the static pod
# stop kubelet because otherwise it will keep runnign and recreate the `member` folder that we want to get rid of to create a new one on snapshot restoration 
sudo systemctl stop kubelet
sudo rm -rf /var/lib/etcd/*  # Clean the old data
# Now restore
sudo etcdutl snapshot restore /path/to/backup.db --data-dir /var/lib/etcd  --bump-revision=1000000000 --mark-compacted
# Put the etcd manifest back
sudo mv /root/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
# restart kubelet
sudo systemctl restart kubelet
```

# fixing restoration issues
The restoration went fine but when trying to exec in pod i got an error: 
```bash
k exec -it nginx-busan-574d67fb55-f427c -- bash cat /usr/share/nginx/index.html
Outputs:
error: unable to upgrade connection: pod does not exist
```
use `crictl` to check on the container runtime and saw that there were an error:
```bash
sudo crictl ps -a | grep nginx-busan
Outputs:
WARN[0000] runtime connect using default endpoints: [unix:///var/run/dockershim.sock unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/c
ri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
ERRO[0000] validate service connection: validate CRI v1 runtime API for endpoint "unix:///var/run/dockershim.sock": rpc error: code = Unavailable desc = connection erro
r: desc = "transport: Error while dialing: dial unix /var/run/dockershim.sock: connect: no such file or directory" 
WARN[0000] image connect using default endpoints: [unix:///var/run/dockershim.sock unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri
-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
ERRO[0000] validate service connection: validate CRI v1 image API for endpoint "unix:///var/run/dockershim.sock": rpc error: code = Unavailable desc = connection error:
 desc = "transport: Error while dialing: dial unix /var/run/dockershim.sock: connect: no such file or directory"
```

So here the issue might be caused because have restarted kubelet before mv back the manifest `etcd.yaml` file, which might have overwrittern the `member` so altered the configs...
so will restart a new restoration from scratch again following the right steps..

- so after search have seen that there could be an issue when the `/var/lib/etcd/member/snap/` number is older than what the cluster is expecting so having it always increasing , so when restoring need to use some flags for that to be done artificially: `--bump-revision and --mark-compacted`
source: (etcd doc about incrementation of numebrs)[https://etcd.io/docs/v3.5/op-guide/recovery/#:~:text=In%20the%20context%20of%20Kubernetes,effectively%20invalidating%20its%20informer%20caches]
- also if several controllers all need to be stopped when doing a `etcd` restoration, see (doc)[https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#:~:text=If%20any%20API%20servers%20are,these%20steps%20to%20restore%20etcd]

more general docon restoration from `etcd`: (kubernetes restoration doc)[https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#:~:text=]

- so need to use command to restore: 
get revision number of your snapshot so that you know what incremental number you can use in your restoration command:
eg.:
```bash
sudo ETCDCTL_API=3 etcdutl snapshot status snapshots/busan-creditizens-home.db
Outputs:
80ae79f1, 615876, 1618, 12 MB
sudo ETCDCTL_API=3 etcdutl snapshot status snapshots/hawaii-creditizens-house.db 
Outputs:
27402943, 620774, 1151, 12 MB
```
`--mark-compacted` ensures that any attempt to read older revision data (like what old controllers cached) is rejected, forcing them to re-list everything.
```bash
sudo etcdutl snapshot restore snapshot.db --data-dir=/var/lib/etcd \ 
    --bump-revision=1000000000 --mark-compacted
```
fter this fix so adding those flags `--bump-revision` bigger than last snapshot and `--mark-compacted` for history to restart form there and not look at state data cached or other from any components of the controller (scheduler, apiserver, controlle manager)

**Important Point to Consider to Not Get Errors In Restoration**
**- make sure all control plane are down to avoid state issues with one control plane having still to reference to older journal logs of state**
**- so stop `kubelet` and mv `etcd.yaml` manifest on all of those**
**- use the `--bump-revision` number flag and the other flag `--mark-compacted` to compact whatever is lower so that the cluster initializes state fromt he snapshot point**
**- if other resources have been created since the snapshot has been done, need to reuse those yaml files to get it back so you get the desire state**
**- if having issues with `tokens`, get rid of `secrets` which will be recreated**
**- make sure to copy the restored /var/lib/etcd/member/ in all other `controller` nodes using `ssh` or other means.**
**- after on all nodes mv back the `etcd.yaml` manifest file and restart `kubelet`
**- the issue is not from using `etcdutl` or `etcdctl` for restoration, you can use `etcdctl` for snapshot creation and the other `etcdutl` for restoration. The issue is more due to other components of the cluster having state of the older cluster. so mistmatch between snapshot state and some controller plane components ones. = `stale watches` issues.**
