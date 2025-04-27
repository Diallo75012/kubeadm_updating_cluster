# Kubernetes Patching Deployment
Here we will use a side `.yaml` file to patch our deployment:
- if the keys names are the same as in the initial deployment the field will be updated
- if the keys names are different those will be added to the deployment
- therefore, **make sure you choose the name of the keys carfully**

- here have added a `configMap` as a mounted volume to the `nginx` deployment
```bash
cat config-map.yaml 
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-html
  namespace: nginx
data:
  index.html: |
    <h1 style="color:red;">Creditizens Customized Page Red</h1>
```

- here we create the side file that target the fields that will be updated
```bash
cat nginx-deployment-patching.yaml 
```
```yaml
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: nginx-html-conf
          mountPath: /usr/share/nginx/html/
      volumes:
      - name: nginx-html-conf
        configMap:
          name: nginx-html
```

- now patch deployment and you will see that nginx pages are displaying the red message `Creditizens Page Red`
```bash
# apply patch
kubectl patch deployment nginx -n nginx --type merge --patch-file nginx-deployment-patching.yaml
# update deployment (will start new pod and make the rolling update of those with default 25% surge)
kubectl rollout restart deployment/nginx -n nginx
```
