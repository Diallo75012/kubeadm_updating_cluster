# DNS ACCESSING PODS THROUGH SERVICES USING NAMES

## PODS IN SAME NAMESPACE
As IPs can change there is in Kubernetes native `DNS` resolution:
- services need to be created first (before pod for the pod to be able to capture the env var set automaticcally by Kubernetes) if using IPs instead
  but in general using DNS name of the POD and SVC and NAMESPACE and CLUSTER would reolve to accessing the pod.
- `resolv.conf` file is where the DNS of the service will be indicated

```bash
k exec -it -n nginx nginx-pod -- sh
# cat /etc/resolv.conf
search nginx.svc.cluster.local svc.cluster.local cluster.local localdomain
nameserver 10.96.0.10
options ndots:5
```
So here the service name `nginx` is indicated in the `resolv.conf` file for the pod to be reached at `<pod_name>.nginx.svc.cluster.local`
So another pod in another namespace could pass throught the `ClusterIP` service named `nginx` in the namespace `nginx` and find the pod

**Experiement DNS Using Imperative Commands**
We will make a service that has a `spec.selector` pointing to a pod `label` and will create the pod with the same label , all in same namespaces
As we are using `names` we will be able to use `DNS` names and `not unstable` `IPs`, therefore, there is no rule in the order in which we will create the service, it can be after or before the pod creation

. 1) Run pod with label
```bash
k run nginx --image=nginx \
  --restart=Never \
  --namespace=nginx \
  --labels=app=nginx
```

. 2) Expose the pod to enable `DNS` resolution through a service `nginx-service` with a `selector` pointing to the `pod` `label`
After that we need to expose the service to get `DNS` `nginx-service.nginx.svc.cluster.local` ready and callable from anyu other pod in the cluster:
Here we do something easy to understand but policies can be created to limit access to only pods inside the same namespace for example as namespaces are made for that to separate concerns:
```bash
k expose pod nginx \
  --port=80 \
  --target-port=80 \
  --name=nginx-service \
  --namespace=nginx \
  --selector=app=nginx
```

. 3) Create another temparary pod to test that `nginx` pod is reachable through `DNS` resolution `nginx-service.dev.svc.cluster.local`
```bash
k run debug --rm -it --image=busybox --restart=Never \
  --namespace=nginx -- /bin/sh

# curl not available so used wget which pooled the `index.html` page meaning that the pod is accessible through the service
wget http://nginx-service
Outputs:
Connecting to nginx-service (10.110.245.196:80)
saving to 'index.html'
index.html           100% |************************************************************************************************************************|   615  0:00:00 ETA
'index.html' saved

# then we cat the file pulled
cat index.html 
Outputs:
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
outputs

# nslookup
# nslookup nginx-service.nginx.svc.cluster.local
Server:         10.96.0.10
Address:        10.96.0.10:53


Name:   nginx-service.nginx.svc.cluster.local
Address: 10.110.245.196
```
so here we get confirmation


## DNS RESOLUTION FROM POD IN ANOTHER NAMESPACE

. 4) Check if other pods in other namespaces can use the `DNS` to reach the pod
Here pod created in `default` namespace and will access the pod in `nginx` namespace using the `DNS` which maps the `pod` through the `service` name
```bash
k run debug --rm -it --image=busybox --restart=Never -- /bin/sh
If you don't see a command prompt, try pressing enter.

# nlookup way
/ # nslookup nginx-service.nginx.svc.cluster.local
Outputs:
Server:         10.96.0.10
Address:        10.96.0.10:53


Name:   nginx-service.nginx.svc.cluster.local
Address: 10.110.245.196

# wget way but this this time as we are not in same namesapce we need to provide full `DNS` with namespace
/ # wget nginx-service.nginx.svc.cluster.local
Outputs
Connecting to nginx-service.nginx.svc.cluster.local (10.110.245.196:80)
saving to 'index.html'
index.html           100% |************************************************************************************************************************|   615  0:00:00 ETA
'index.html' saved

# then we check that the file is nginx index.html
/ # cat index.html 
Outputs:
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## SETTING POD DNS RESOLV.CONF CONTENT FROM YAML CREATION
eg: source: (form doc kubernetes)[https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/]
```yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  # can be `Default`, `Clusterfirst`, `ClusterFirstWithHostNet` or `None`
  # when `None` we can custom config  `resolv.comf` of the pod
  dnsPolicy: "None"
  # all fields are not required, you can just choose to use one
  # or `nameservers`, or `searches` or `options`
  # but if you want more control you probably want to use them all
  dnsConfig:
    # get the `nameserver ip of the cluster by running this command:
    # kubectl get svc -n kube-system kube-dns
    :nameservers:
      - 10.96.0.10
    # here we put what services we want to reach using Kubernetes DNS way
    searches:
      # <service_anme.name_space.cluster.local>
      # or <namespace.cluster.local>
      - ns1.svc.cluster.local
      - my.dns.search.suffix
    # example of options that you find in `/etc/resolv.conf`
    options:
      # `ndots` is if lower thant `2` dots here
      # will try append the above `searches` to the `curl <domain>`
      # so will try `<domain>.ns1.svc.cluster.local`
      # then will try `<domain>.my.dns.search.suffix` if the first doesn't work and so on...
      - name: ndots
        # higer value more checks and latency, lower value better performance but could skip some
        value: "2"
      - name: edns0
      - name: timeout
        value: "2"
```

- `dnsPolicy` can take different values:
dnsPolicy| Description|Use When
------------+---------------+-----------
ClusterFirst (default)| Uses cluster DNS (CoreDNS). Can resolve Kubernetes service names across namespaces.| ✅ Most common for standard Pods|
------------------------+---------------------------------------------------------------------------------------+----------------------------------+
ClusterFirstWithHostNet| Same as above but used when Pod uses hostNetwork: true| ✅ Use when Pod shares host network|
------------------------+-----------------------------------------------------------+-------------------------------------+
DefaultUses the node’s /etc/resolv.conf. | Can’t resolve Kubernetes service DNS.| ❌ Avoid unless you want to use external DNS only|
------------------------------------------+-----------------------------------------+--------------------------------------------------+
None| Lets you manually define DNS config via dnsConfig in the Pod spec| ✅ Use if you want full custom DNS entries, e.g., override search domains or stub resolvers|
--------+-------------------------------------------------------------------+--------------------------------------------------------------------------------------------+

**Summary**
- `ClusterFirst`: is the default one using CorDNS of Kubernetes
- `ClusterfirstWithHostNet`: Only when `hostNetwork: true`, when pod shares host network
- `Default`: not the 'default' as the name says this only for external DNS
- `None`: when setting custom DNS in pods via `dnsConfig` (/etc/resolv.conf)
  - `nameservers` ip of the cluster is given by CoreDNS `kube-dns` in `kube-system` namespace:
```bash
kubectl get svc -n kube-system kube-dns
Outputs
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   630d
```


## SETUP NETWORK POLICY AS DNS IS RESOLVING ANY SERVICE MAPPED TO POD INSIDE THE CLUSTER
source: (Network Policies Doc)[https://kubernetes.io/docs/concepts/services-networking/network-policies/]

**Important:** By default the Kubernetes allow all traffic and only when you set a rules it will deny all other rules:
`kind: NetworkPolicy` is deny all when set and in the policy you are going to allow `ingress`/`egress`
therefore, you just set the policy and put what is allowed in the rest will be denied.
And this denial is activated because you have set a rule `ingress` or `egress`. without rule all is allowed.


here we have an example in how to setup a policy.
`ingress` and `egress` can be setup, refer to documentation for `egress` as here we are going to do only `ingress`
`egress` is the same anyway but just you replace `ingress` examples with `egress` or just refer to doc as it might change


### INGRESS:
- (Ingress rules) allows connections to all pods in the default namespace with the label role=db on TCP port 6379 from:
      - any pod in the default namespace with the label role=frontend
      - any pod in a namespace with the label project=myproject
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
            # we just see `namespaceSelector` and `podSelector` not the third one `ipBlock`
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
```

### DENY ALL

eg: deny all traffic
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### ANDed VS ORed RULES

eg: ANDed vs ORed
- ANDed
```yaml
  ingress:
  # here `single` element in the `- from` (`- namespaceSelector`) which make it `ANDed`
  - from:
    # note here that here only `namespaceSelector` have the `-` which enabled the `AND`for the next rule `podSelector`
    - namespaceSelector:
        matchLabels:
          user: alice
      podSelector:
        matchLabels:
          role: client
```
- ORed
```yaml
  ingress:
  # here two elements in the `- from` (`- namespaceSelector`, `- podSelector`) which makes it ORed
  - from:
    - namespaceSelector:
        matchLabels:
          user: alice
    # note that here we have `-` which is enabling the `OR` instead of `AND`
    - podSelector:
        matchLabels:
          role: client
```


1) scenario that shows how dns works, very simple, within same namespace creating pod and exposing with a service and creating a third pod that would use dns to access the pod using DNS (curl/wget/nslookup whatever works)
then do same scenario but this time the third pod is created outside of the namespace and curl/wget/nslookup again to show that DNS means that pods from other namespaces can resolve to the pod using DNS call

2) do another scenario showing now how to setup a pods and determining the reolv.conf of the pod content so that pod can call that other pod through another service dedicated to that other pod. maybe customize nginx in that namespace with different one and different messages index.html pages and having each different services attached to those. and go inside pod to show that it can resolve that pod
eg: source: (form doc kubernetes)[https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/]
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: dns-example
spec:
  containers:
    - name: test
      image: nginx
  dnsPolicy: "None"
  dnsConfig:
    nameservers:
      - 192.0.2.1 # this is an example
    searches:
      - ns1.svc.cluster-domain.example
      - my.dns.search.suffix
    options:
      - name: ndots
        value: "2"
      - name: edns0

3) now make it more complexe by making this example more interesting by adding a network policy as before even if not in resolv conf the pod could use the kubernetes native dns call to reach the other pod anyway, but this policy would say no ingress accepted from other namespaces for that pod specifically but the other pod would be still reachable
source services can be created with name on ports which would be included in the DNS to target that port so the service behind it, can be nice to use to target the different nginx behind it with different html pages: (doc)[https://kubernetes.io/docs/concepts/services-networking/service/]
o here say that network plugins are required and that we are using `Calico` already installed in the cluster and it is a prerequisite
  - example from doc:
    - (Ingress rules) allows connections to all pods in the default namespace with the label role=db on TCP port 6379 from:
      - any pod in the default namespace with the label role=frontend
      - any pod in a namespace with the label project=myproject
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
            # we just see `namespaceSelector` and `podSelector` not the third one `ipBlock`
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
```

eg: deny all traffic
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

eg: ANDed vs ORed
- ANDed
```yaml
  ingress:
  # here `single` element in the `- from` (`- namespaceSelector`) which make it `ANDed`
  - from:
    # note here that here only `namespaceSelector` have the `-` which enabled the `AND`for the next rule `podSelector`
    - namespaceSelector:
        matchLabels:
          user: alice
      podSelector:
        matchLabels:
          role: client
```
- ORed
```yaml
  ingress:
  # here two elements in the `- from` (`- namespaceSelector`, `- podSelector`) which makes it ORed
  - from:
    - namespaceSelector:
        matchLabels:
          user: alice
    # note that here we have `-` which is enabling the `OR` instead of `AND`
    - podSelector:
        matchLabels:
          role: client
```

### ALLOW ALL INGRESS
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
```

k run nginx-pod --port=80  --labels=location=shibuya --image=nginx
k run debug --rm -it --image=busybox --restart=Never   --namespace=nginx -- /bin/sh
k expose pod nginx   --port=80   --target-port=80  --namespace=nginx
k expose pod nginx-pod --port=80 --target=port=80 --name=nginx-service --selector=location=shibuya --type=NodePort

# networkpolicy to prevent all ingress traffic to hachiko pod and permit only the right labelled namespace and the right labelled pod
cat network-policy-aishibuya-hachiko.yaml 
# network-policy-aishibuya-hachiko.yaml NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: aishibuya-network-policy
  namespace: aishibuya
spec:
  podSelector:
    matchLabels:
      shibuya-location: hachiko
  policyTypes:
  - Ingress
  ingress:
  - from:
    # ANDed as no `-` at `podSelector`
    - namespaceSelector:
        matchLabels:
          # need to label the default namespace with that `zone=tokyo`
          zone: tokyo
      podSelector:
        matchLabels:
          shibuya-fan: access
    ports:
    - protocol: TCP
      port: 80
#spec:
#  podSelector: {}
#  policyTypes:
#  - Ingress


# pods running in defaultnamespace which will be used in `exec -it` mode to use dns lookups, busybox for nslookup and nginx pods with different labels for curl commands
cat pod_resolv_conf_services_without_netpolicy_busybox.yaml 
# pod_resolv_conf_services_having_netpolicy_busybox.yaml Pod
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: busy-tokyo
  #name: nginx2-tokyo
spec:
  containers:
    #- name: nginx2-tokyo-connect-to-aishibuya
    #  image: nginx
    - name: busy-tokyo-connect-to-aishibuya
      image: busybox:1.35
      # this necessary as busybox exits and pod will never stay alive so we need to sleep it for a while so we can do our work
      command: ["sleep", "36000"]
  # can be `Default`, `Clusterfirst`, `ClusterFirstWithHostNet` or `None`
  # when `None` we can custom config  `resolv.comf` of the pod
  dnsPolicy: "None"
  dnsConfig:
    # obtained ip by running: `kubectl get svc -n kube-system kube-dns`
    nameservers:
      - 10.96.0.10
    # here we put what services we want to reach using Kubernetes DNS way
    searches:
      # <name_space.cluster.local>
      # OR also can add: <service_name.namespace.svc.cluster.local>
      - aishibuya.svc.cluster.local
    options:
      - name: ndots
        value: "5"

cat pod_resolv_conf_services_without_netpolicy_nginx2.yaml
# pod_resolv_conf_services_having_netpolicy_nginx2.yaml Pod
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  #name: busy-tokyo
  name: nginx2-tokyo
spec:
  containers:
    - name: nginx2-tokyo-connect-to-aishibuya
      image: nginx
    #- name: busy-tokyo-connect-to-aishibuya
      #image: busybox:1.35
      # this necessary as busybox exits and pod will never stay alive so we need to sleep it for a while so we can do our work
      #command: ["sleep", "36000"]
  # can be `Default`, `Clusterfirst`, `ClusterFirstWithHostNet` or `None`
  # when `None` we can custom config  `resolv.comf` of the pod
  dnsPolicy: "None"
  dnsConfig:
    # obtained ip by running: `kubectl get svc -n kube-system kube-dns`
    nameservers:
      - 10.96.0.10
    # here we put what services we want to reach using Kubernetes DNS way
    searches:
      # <name_space.cluster.local>
      # OR also can add: <service_name.namespace.svc.cluster.local>
      - aishibuya.svc.cluster.local
    options:
      - name: ndots
        value: "5"

cat pod_resolv_conf_services_having_netpolicy.yaml 
# pod_resolv_conf_services_having_netpolicy.yaml Pod
apiVersion: v1
kind: Pod
metadata:
  namespace: default
  name: nginx-tokyo
  labels:
    shibuya-fan: access
spec:
  containers:
    - name: nginx-tokyo-connect-to-aishibuya
      image: nginx
  # can be `Default`, `Clusterfirst`, `ClusterFirstWithHostNet` or `None`
  # when `None` we can custom config  `resolv.comf` of the pod
  dnsPolicy: "None"
  dnsConfig:
    # obtained ip by running: `kubectl get svc -n kube-system kube-dns`
    nameservers:
      - 10.96.0.10
    # here we put what services we want to reach using Kubernetes DNS way
    searches:
      # <name_space.cluster.local>
      # OR also can add: <service_name.namespace.svc.cluster.local>
      - aishibuya.svc.cluster.local
    options:
      - name: ndots
        value: "5"


k get pods
NAME           READY   STATUS    RESTARTS   AGE
busy-tokyo     1/1     Running   0          93m
nginx-tokyo    1/1     Running   0          50m
nginx2-tokyo   1/1     Running   0          5s

# pods applied to the cluster with different config maps for different messages display and configmaps in one unique file
cat nginx_aishibuya_tsutaya_pod.yaml 
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
    shibuya-location: tsutaya
  name: nginx-tsutaya
  namespace: aishibuya
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: creditizens-aishibuya-custom-message
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: creditizens-aishibuya-custom-message
    configMap:
      name: aishibuya-tsutaya-message


cat nginx_aishibuya_hachiko_pod.yaml 
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx
    shibuya-location: hachiko
  name: nginx-hachiko
  namespace: aishibuya
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: creditizens-aishibuya-custom-message
      mountPath: /usr/share/nginx/html/
  volumes:
  - name: creditizens-aishibuya-custom-message
    configMap:
      name: aishibuya-hachiko-message

cat config_maps_for_aishibuya.yaml 
# config_map_for_aishibuya.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: aishibuya-hachiko-message
  namespace: aishibuya
data:
  index.html: |
    <html>
    <h1 style="color:green;">Hachiko Statute Will Be Renovated</h1>
    </br>
    <h1 style="color:green;">The Refreshed Hachiko Will Be Available From December 2025.</h1>
    </html>

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: aishibuya-tsutaya-message
  namespace: aishibuya
data:
  index.html: |
    <html>
    <h1 style="color:orange;">Starbuck Will Be Closed Till November 2025</h1>
    </br>
    <h1 style="color:red;">But Tsutaya Upper Stairs Will Still Be Open.</h1>
    </html>


# the services applied to cluster
cat hachiko-service.yaml 
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: hachiko-service
  namespace: aishibuya
spec:
  ports:
  - name: access-hachiko
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    shibuya-location: hachiko
  type: ClusterIP

cat tsutaya-service.yaml 
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: tsutaya-service
  namespace: aishibuya
spec:
  ports:
  - name: access-tsutaya
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    shibuya-location: tsutaya
  type: ClusterIP

k get svc -n aishibuya 
NAME              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
hachiko-service   ClusterIP   10.101.194.141   <none>        80/TCP    13m
tsutaya-service   ClusterIP   10.111.135.216   <none>        80/TCP    13m


# getting th epods to see if matching service backend (just after this step)
k get pods -o wide -n aishibuya 
NAME            READY   STATUS    RESTARTS   AGE   IP              NODE                    NOMINATED NODE   READINESS GATES
nginx-hachiko   1/1     Running   0          71m   172.16.210.82   node2.creditizens.net   <none>           <none>
nginx-tsutaya   1/1     Running   0          70m   172.16.206.71   node1.creditizens.net   <none>           <none>

# can't reach the pod that has an ingress policy because the label of the pod not matching even if the namespace label matches (we used ANDed rule)
kubectl get endpoints hachiko-service -n aishibuya
NAME              ENDPOINTS          AGE
hachiko-service   172.16.210.82:80   10s  # correctly pointing to only one pod behind the service and it is the right one (right ip, see above get pods)
k exec -it nginx2-tokyo -- bash
root@nginx2-tokyo:/# curl tsutaya-service.aishibuya.svc.cluster.local
<html>
<h1 style="color:orange;">Starbuck Will Be Closed Till November 2025</h1>
</br>
<h1 style="color:red;">But Tsutaya Upper Stairs Will Still Be Open.</h1>
</html>
root@nginx2-tokyo:/# curl hachiko-service.aishibuya.svc.cluster.local
^C
root@nginx2-tokyo:/# curl hachiko-service.aishibuya.svc.cluster.local
^C



# can access to the right pod as it is matching policy labels for namespace and pod origin
k get pods
NAME           READY   STATUS    RESTARTS   AGE
busy-tokyo     1/1     Running   0          114m
nginx-tokyo    1/1     Running   0          71m
nginx2-tokyo   1/1     Running   0          21m
k exec -it nginx-tokyo -- bash
root@nginx-tokyo:/# curl tsutaya-service.aishibuya.svc.cluster.local
<html>
<h1 style="color:orange;">Starbuck Will Be Closed Till November 2025</h1>
</br>
<h1 style="color:red;">But Tsutaya Upper Stairs Will Still Be Open.</h1>
</html>
root@nginx-tokyo:/# curl hachiko-service.aishibuya.svc.cluster.local
<html>
<h1 style="color:green;">Hachiko Statute Will Be Renovated</h1>
</br>
<h1 style="color:green;">The Refreshed Hachiko Will Be Available From December 2025.</h1>
</html>
root@nginx-tokyo:/# 

# can still nslookup but this stops at the service and gets the ips of backend and ports
k exec -it busy-tokyo -- sh
/ # nslookup _access-tsutaya._tcp.tsutaya-service.aishibuya.svc.cluster.local
Server:10.96.0.10
Address:10.96.0.10:53


Name:_access-tsutaya._tcp.tsutaya-service.aishibuya.svc.cluster.local
Address: 10.103.229.167

/ # nslookup _access-hachiko._tcp.hachiko-service.aishibuya.svc.cluster.local
Server:10.96.0.10
Address:10.96.0.10:53

Name:_access-hachiko._tcp.hachiko-service.aishibuya.svc.cluster.local
Address: 10.101.83.147
