# Kubernetes Commands `CLI`

- Use `kubeconfig` file to authenticate to cluster
```bash
kubectl get pods --kubeconfig ~/.kube/config -A
```

- `--raw` flag to see sensitive data and raw bytes data
source: [doc about --raw](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_view/)
source: [doc about --raw](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/)
```
--raw string
Raw URI to request from the server. Uses the transport specified by the kubeconfig file.
```

Eg.:
```bash
# this shows sensitive data of the kubeconfig certs/keys (base64 encoded so as those are displayed in the file)
kubectl config view --raw
# can use raw URL to have resources info
kubectl get --raw /api/v1/namespaces/default/pods
{"kind":"PodList","apiVersion":"v1","metadata":{"resourceVersion":"104637"},"items":[]}
```

- Authentication RBAC
```bash
kubectl auth whoami
ATTRIBUTE   VALUE
Username    kubernetes-admin
Groups      [system:masters system:authenticated]
```

- Create User And Provide Access Using Cert Creation Way
source: [User Permission Access: Cert Creation Way](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
source: [Authorisation](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
```bash
# create key
openssl genrsa -out key_creditizens.pem
```
```bash
# create certificate signing request with username and organizations (different groups)
openssl req -new -key key_creditizens.pem -out creditizens.csr -subj "/CN=creditizens/O=devops/O=sre/O=genaiops"
```
```bash
# extract the base64 encode key `csr` in a one liner for the next .yaml file that we are going to embedded into
cat creditizens.csr | base64 | tr -d '\n'
```
source: (but version 1.27 not available so will try with my hold notes) [doc for v1.28](https://v1-28.docs.kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
source where `yaml` file is found: [Managing TLS in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
```yaml
# create `yaml` file `kind: CertificateSigningRequest`
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  # this will be username
  name: creditizens
spec:
  groups:
  - system:authenticated
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ2pUQ0NBWFVDQVFBd1NERVVNQklHQTFVRUF3d0xZM0psWkdsMGFYcGxibk14RHpBTkJnTlZCQW9NQm1SbApkbTl3Y3pFTU1Bb0dBMVVFQ2d3RGMzSmxNUkV3RHdZRFZRUUtEQWhuWlc1aGFXOXdjekNDQVNJd0RRWUpLb1pJCmh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBS09DQWVCR3h4WVQ5U1VHNGtWZVRNNlJmVlhEdlVMTTBuM3cKYlNKa1AyYW5XRHozSm5QQ003MFBLNmo3cWNpakxyL0czcVkrMzVvL0pYeXJVL0hJOVRxaXNxeTRvT1kxa1ZEawo2amNKVGhhd1hJNExtT0dDNFVkSENVVGhQYTVBZkZMMjZ1RmNNWDZ0ZGh2MWtTa0NSNXJUSmlPbFg5MWtsWm83ClE5S3lhdDVNQ1hNTm1iZXFkVTRVY1NWZ0NaOTlJNHdLSy9KQytVMHR4amNPUzdNd04wekJJL2VSM29XOFhZS3AKMEFXWUw1MVRhRHNpM1hLSW9WMTFrVXFqeERtNGI4Qy9pMFRJbDRDMVJIUmtCNmVJbnQwbFcxSjk0aDZ1UmEvNAphYUlnS1lxcEQ0WjBpaE9CRGl5dkNVcTVRS1FvTVVXWXlsZ2IwUzVhcHVEbkRiNUxkVTBDQXdFQUFhQUFNQTBHCkNTcUdTSWIzRFFFQkN3VUFBNElCQVFCTUs1ZGJUekZWOXBIM3g3Mk9SMm56TzhoQnQzSGdySGplZ1ZkVlZ4dEUKR3N6bHZXemw2S3gxb25zQlhmdTcvWWdIbUlMZG5EdmdTaCtzSUhKUkNpNDR3TmRhQmZtdHl1L0pSTFFUbmVEZQozb0JSY0tnZHZrclRQVWZieittMGRXUGVRemVWU3BUS1F6dytBK0ZGcURtbTYwano2ZWc4ZnNjVkpZSCtBTlhjCm1zcGZFeTBhdDNEbjJpelNZZmRaVlNrWTc2cjFUclpNNXdaWVA5WXo1U1Y5NHVMR2ZhYWlrblErMEw0Zm80OUoKM0JESFllRXMzZHZFbFJ3Zk9MSVpBaUYwOEowNmdYMmtHajFiTk1taHNDdGY4T2RTVzZwYktBUVhxMDVZeDJxNwp1ODR0UU9zZXlLNDFwNVpCUDdEYVBsU3ZocVFDMFZKbHVtNDE0TzZxR0JodwotLS0tLUVORCBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
  # this is just full name
  username: "creditizens metaverse"
```
```bash
# apply yaml file
kubectl apply -f auth_creditizens_to_api_server_component_create.yaml 
```
source: [approve csr](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
```bash
# get csr using `kubectl` command and approve user
kubectl get csr
# approve the name of the csr which the the username choosen int he `yaml` file
kubectl certificate approve creditizens
```
```bash
# check the yaml version of the kuebrnetes `csr`
kubectl get csr creditizens -o yaml
# then extract from it the certificate and save it in a file for the user to be able to use that `crt` (situated at `.status.certificate`)
kubectl get csr creditizens -o jsonpath='{.status.certificate}' | base64 -d > creditizens.crt
```
source: [imperative command](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/imperative-command/)
source: [imperative all kubetcl command doc](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)
```bash
# create namespace (Optional as you can leave it to default namespace)
kubectl create ns aishibuya
# create role
kubectl create role aidevops --verb=create,get,update,delete,list --resource=pods -n aishibuya
```
```bash
# create a role binding
kubectl create rolebinding deployment-ai-apps-creditizens --user=creditizens --role=aidevops -n aishibuya
```
```bash
# now set credentials for the user using key(`.pem` or `.key` if used `-in <....>.key` when using the openssl command but choose `.pem` way) and crt
# so now those credential are added to kubeconfig
kubectl config set-credentials creditizens --client-key=key_creditizens.pem --client-certificate=creditizens.crt --embed-certs=true
```
```bash
# set the context for this user that will use previously added credentials in the kubeconfig file (~/.kue/config)
kubectl config set-context creditizens --user=creditizens --cluster=kubernetes
```
```bash
# switch to the new user context and it will be limited to the namespace `aishibuya` and only `pod` resource (delete, get, list, create..)
kubectl config use-context creditizens
```
```bash
# swith context
kubectl config use-context kubernetes-admin@kubernetes
# delete context created and it will disappear from the '~/.kube/config' file
kubectl config delete-context creditizens
# check user is not anymore in `~/.kube/config`
cat ~/.kube/config
