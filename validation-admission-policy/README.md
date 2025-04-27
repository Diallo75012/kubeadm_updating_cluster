# Validation Admission Policy
Source: (doc admission policy)[https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/]
```bash
k api-resources | grep "validating"
validatingwebhookconfigurations                admissionregistration.k8s.io/v1        false        ValidatingWebhookConfiguration
```
"`Validating admission policies` offer a declarative, **in-process alternative** to `validating admission webhooks`"

**x3 resources are needed to have a `validatingAdmissionPolicy` setup:**
- a `ValidationAdmissionPolicy`: That is the main subset of the policy which enforces a behaviour check or restriction.
- `parameter resources`: Some resources defined with some expressions constraint or precision in order for the `ValidatingAdmissionPolicy` to know parameter of the `kind:` (ConfigMap, CRD, Pod, etc...) that need to be fulfilled. (optional can also not be set, if so, do not specify `spec.paramKind` in `ValidatingAdmissionPolicy`. What is interesting with `parameter resources` is that we can create our custom `yaml` with our custom `apiVersion:` and custon `kind:` and use any custum fields after `metadata:` (which even if custom can be namespaced or not). Then in the `ValidatingAdmissionPolicy` use `paramKind` to reference it and use the `matchExpression` to check against it and in the other hand in `ValidatingAdmissionPolicyBinding` have a `paramRef` and also reference it there.
- q `ValidatingAdmissionPolicyBinding`: here is the one making the `ValidationAdmissionPolicy` and the `parameter resources` to be linked. Even when we don't have `paramter resources` specified, this `ValidatingAdmissionPolicyBinding` is mandatory and the minimal set up is `ValidatingAdmissionPolicy` with `ValidatingAdmissionPolicyBinding` (and `spec.paramKind` not specified in `ValidatingAdmissionPolicy`)

## a `ValidatingAdmissionPolicy`
(eg. from kubernetes doc.)
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: "demo-policy.example.com"
spec:
  # if not set would default to `Fail`, if set and not to `Fail` the `validations` would be ignored
  # can be set also to `Ignore`. here it check what happens if Kubernetes can't verify this validation expression.
  failurePolicy: Fail
  matchConstraints:
    # apply `admission policy` only to resource `deployment` when it is `created` and `updated` and it is part of the `v1` API and `apps` API group
    resourceRules:
    - apiGroups:   ["apps"]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["deployments"]
  # if `true` all good, if `false` so different would enforce the above option `failurePolicy`
  # and `Fail` here as this is what it is set. (if other can be ignored as well)
  validations:
    - expression: "object.spec.replicas <= 5"
```
Here: `resourceRules` is the "selector" of what kind of object (Deployment, Pod, etc.) and on what kind of action (Create, Update, Delete) the policy must run.

## a `ValidatingAdmissionPolicyBinding`
different values that can be taken by `validationActions` in `ValidatingAdmissionPolicyBinding`:
- `Deny`: Validation failure results in a denied request. Can be used with `Audit`: [`Deny`, `Audit`] , can't be used with `Warn` as opposite effects.
- `Warn`: Validation failure is reported to the request client as a warning. Can be used with `Audit`: [`Warn`, `Audit`], can't be used with `Deny` as opposite.
- `Audit`: Validation failure is included in the audit event for the API request. can be used with either of both `Deny` and `Warn` BUT NOT alone.
**So here it will also be enforced depending on the other resource it is binded to the `validatingAdmissionPolicy`'s `failurePolicy`**
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: "demo-binding-test.example.com"
spec:
  # linking to `ValidatingAdmissionPolicy`
  policyName: "demo-policy.example.com"
  # here enforced check, what happends when the `ValidatingAdmissionPolicy` referenced in `policyName` return `false` (expression not validated)
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        environment: test
```

### is `validationActions` in `ValidatingAdmissionPolicy` redundant when we have `failurePolicy` in `ValidatingAdmissionPolicy`

Look like YES but actual it is NOT as they both check different things:
Role                                                    | Purpose
failurePolicy (in ValidatingAdmissionPolicy)            | What happens **if the admission check system itself is broken** or unreachable (for example, the expression engine is unavailable, server crashes) — **Should the API server fail or ignore** the check? (meta failure handling)
validationActions (in ValidatingAdmissionPolicyBinding) | **What** to do **when the expression runs fine but returns FALSE** (meaning the object **failed validation**) — **Should it deny, warn, or audit?** (actual check result handling)

#### Examples to understand the workflow (as a bit complicated)
ValidatingAdmissionPolicy defines:
```yaml
validations:
  - expression: "object.spec.replicas <= 5"
failurePolicy: Ignore
```
ValidatingAdmissionPolicyBinding defines:
```yaml
validationActions: [Deny]
namespaceSelector:
  matchLabels:
    environment: dev
```
If I create a Deployment in a namespace labeled environment=dev with replicas: 10, here is what happens:
- Selector matches → ValidationPolicy triggered
- Expression evaluated → returns false (because 10 > 5)
- Engine is working (no crash) → so failurePolicy not triggered.
- Expression false → validationActions: Deny → Request denied.

#### Another Example:
- .1) User sends object to API Server.
- .2) Binding: matchResources (selector) checked → Does this policy apply?
    - If yes, proceed.
    - If no, nothing else happens.
- .3) Policy: ValidatingAdmissionPolicy applied → Expression evaluated.
- .4) If evaluation:
    - Crashes → failurePolicy (Fail or Ignore) is checked.
    - Succeeds:
      - If expression true → allow.
      - If expression false → validationActions (Deny / Warn / Audit) decides.


**NOTES:**
- `validationActions` = what happens if rule is violated (false).
- `failurePolicy` = what happens if Kubernetes itself can't even run the check.

**So to resume the understanding:**
- I apply resoruce to cluster
- If in the `ValidatingAdmissionPolicyBinding` the selector i not triggered this `admissing policy` won't be enforeced. In the other hands, if it matches the s2lector (True) it will then check the `ValidatingAdmissionPolicy` 'binded' to it and indicated in `policyName`.
- Then in the `ValidatingAdmissionPolicy` the expression is checked if it is `true` all good `Admission: OK!`, if it is not good `false` (expression condition not respected) it will check the `failurePolicy` indicated and apply it `Fail` (Kubernetes can't validate expression) or `Ignore` (ignore that Kubernetes can't verify because of any issue or just not complying). So this is not yes stoppong anything. it is after.
- Now when the `failurePolicy` is triggered in the `ValidatingAdmissionPolicy` the `validationActions` of the `ValidatingAdmissionPolicyBinding` will apply `War n` and let it deploy with warning thereofre `admit it: OK! but warning !` OR `Deny` it and stop the deployment of the resource so `Not Admited`. `Audit` if present as works in combinaison of any of `Warn/Deny`, it will also include the event int he API Request events.

## a `paramter resource`
we use here example from documentation and will comment it out
custom resource created by admin, `apiVersion:` and `kind:` are all custom
```yaml
# fully custom  `apiVersion:` as there is no controller/CRD or check, it has just to be valid `CEL` language
apiVersion: rules.example.com/v1
# fully custom  `kind:` as there is no controller/CRD or check, it has just to be valid `CEL` language
kind: ReplicaLimit
metadata:
  name: "replica-limit-test.example.com"
  # can specify a namespace, if no namespace it will be `cluster-wise`
  # like `ValidatingAdmissionPolicy/and ValidatingAdmissionPolicyBinding` are cluster-wise`
  namespace: "default"
# custom parameter
maxReplicas: 3
```

`paramKind` used in `ValidatingAdmissionPolicy` to reference the resource `kind:` we are going to check `matchExpressions` against
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: "replicalimit-policy.example.com"
spec:
  # this is evaluated only if the expression match could not be evaluated by kubernetes for any reason syntaxe error or other...
  # otherwise it is the `ValidatingAdmissionPolicyBinding` `validationActions` that is normally triggering the decision, `Deny` or `Warm` or all good if the `match expression` positively evaluated
  failurePolicy: Fail
  # here is the reference of the resource made available to this `ValidatingAdmissionPolicy`
  paramKind:
    apiVersion: rules.example.com/v1
    kind: ReplicaLimit
  matchConstraints:
    resourceRules:
    - apiGroups:   ["apps"]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["deployments"]
  # now validation here can use `params` keyword to access fields in the `resource referenced in `paramKind`
  validations:
    - expression: "object.spec.replicas <= params.maxReplicas"
      # `reason` need to be a valid one: see doc to see list of those otherwise don't put it and Kubernetes will display default
      reason: Invalid
      # `message` can also be used and inside of it you can use `CEL` expressions like `${variable}`, `.size()`, `.startsWith()`, `||`, `&&` (see doc)
      # message: 
```
`paramRef` used in `ValidatingAdmissionPloicyBinding` to tell which resource is made available to check `matchExpression` against in `ValidatingAdmissionPolicy`
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: "replicalimit-binding-test.example.com"
spec:
  # this specified to what `ValidatingAdmissionPolicy` this `ValidatingAdmissionPolicyBinding` is binded to
  policyName: "replicalimit-policy.example.com"
  # This would be actioned if the `validation` `match expression` is `false` so a>9 is a=2 so false. But if this `match expression` evaluation fail at kubernetes level, so like `missing parameter`, `syntaxe error` or other, then the `failurePolicy` is here as backup to make it `Fail` or `Ignore` it.
  validationActions: [Deny]
  # show here the resource made available to check matchExpressions in `ValidatingAdmissionPolicy` referenced here at key `policyName`
  paramRef:
    name: "replica-limit-test.example.com"
    namespace: "default"
  # check this first to see if policy can be triggered, if this is `true` will start checks
  matchResources:
    namespaceSelector:
      matchLabels:
        environment: test
```

**Importnat Notes:**
- polices won't be created if one references and the other not, meaning if one has `paramRef` the other MUST have matching `paramKind`
- Multiple `ValidatingAdmissionPolicyBindings` to one `ValidatingAdmissionPolicy` possible. but not the other way around. But at the end only one would `matchExpressions`
- one `ValidatingAdmissionPolicy` can have multiple `matchConstraints.resourceRules`

## Scenario:
need to activate featuregate, CRDs in `kube-apiserver.yaml`: `--feature-gates=ValidatingAdmissionPolicy=true`
`kube-apiserver` will pickup the change and restart to activate it.
in order to use custom resource need to create `CRD's` defining this new resource so that we can use it in kubernetes and also we need to set `RBAC` for Kubernetes to be able to have read access to those resources.
see (CRD's Doc)[https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions]

### Issues
tried to add feature gate in kubernetes v1.28.15 using same way i did with `SidecarContainer=true` in custom config files customed from boiler plate `kubeadm config print init-defaults > <my custom yaml file>`, updated the controller node ip address and changed the name of the node to the DNS name of the controller node `controller.creditizens.net` and added the feature gates `ValidatingAdmissionPolicy` with the sidecontainer one.
but when used `sudo kubeadm upgrade apply v1.28.15 --config <my cusotm yaml config file>` i got an error even after upgrate to `v1.29.15` same error.
```bash
[upgrade/apply] FATAL: couldn't upgrade control plane. kubeadm has tried to recover everything into the earlier state. Errors faced: failed to obtain static Pod hash fo
r component kube-apiserver on Node controller.creditizens.net: Get "https://controller.creditizens.net:6443/api/v1/namespaces/kube-system/pods/kube-apiserver-controller
.creditizens.net?timeout=10s": dial tcp 192.168.186.146:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher
```
- couldn't deploy `ValidatingAdmissionPolicyBinding` and `ValidatingAdmissionPolicy`, error message: `ensure CRD's are intalled` was the error when `k apply -f <validatingadmissionpolicy custom yaml file>`
  So here we need to activate the `--feature-gates` in `kube-apiserver.yaml`: `ValidatingAdmissionPolicy=true` 
  i had to upgrade to version v1.29.15 as it is easier to setup this feature gate as it is already there by default but need just to add some line in th ekubernetes yaml files.
  Then, I just added in `kube-apiserver.yaml`
```bash
    - --feature-gates=SidecarContainers=true,ValidatingAdmissionPolicy=true
    - --runtime-config=admissionregistration.k8s.io/v1beta1=true
```
  and in /var/lib/kubelet/config.yaml
```bash
featureGates:
  SidecarContainers: true
  ValidatingAdmissionPolicy: true
```
  then just reloaded daemon and restarted kubelet
```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```
And then applied my custom validating admission policy files and policy was enforced , worked fine. now will play with it to make a custom example 

## full scenario used with creation of CRD and RBAC for our custom resource
- `CRD` creation, custom `resource API creation`, `RBAC` roles and binding for kubernetes to be able to read it `system:authentication`
(cat junko-rules.yaml)
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # must be spec.names.plural+"."+spec.group
  name: mangakissa-zones.mister.w.rules
spec:
  # +spec.group
  group: mister.w.rules
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            replicasFriends:
              type: integer
            soundRules:
              type: string
            locationArea:
              type: string
  scope: Namespaced
  names:
    # spec.names.plural+
    plural: mangakissa-zones
    singular: mangakissa-zone
    kind: VolumeNaruto

---
# fully custom `apiVersion` as there will be checks so we need to create CRDs, it just has to be valid `CEL` language
apiVersion: mister.w.rules/v1
# fully custom `kind` as there will be checks so we need to create CRDs, it just has to be valid `CEL` language
kind: VolumeNaruto
metadata:
  name: "watch.naruto.mister.w.com"
  # can specify a namespace, if no namespace it will de `cluster-wise`
  # as `ValidatingAdmissionPolicy/Binding` are `cluster-wise`
  namespace: "mangakissa-zone"
# custom parameters that we can check on using the `expression` check mechanism
replicasFriends: 3
soundRules: "naruto no sound"
locationArea: "shibuya"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: mangakissa-custom-resource-reader
rules:
- apiGroups: ["mister.w.rules"]
  resources: ["mangakissa-zones"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mangakissa-custom-resource-reader-binding
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: mangakissa-custom-resource-reader
  apiGroup: rbac.authorization.k8s.io
```

- `ValidatingAdmissionPolicy`
(cat validating-admission-policy-mangakissa.yaml)
```yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: ValidatingAdmissionPolicy
metadata:
  name: "volume-naruto-policy.creditizens.com"
spec:
  # this is evaluated only if `expression` down there couldn't be evaluated
  # therefore any syntaxe error, or kubernetes can't evaluate it will come here and check the `failurePolicy`
  # can be `Fail` or `Ignore`, if not indicated, default to `Ignore`
  failurePolicy: Fail
  # here is the reference of the resource made available to this policy to check on
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  # now validation here can use an exprssion to check if condition is satisfied or not
  # when these `validations` can be evaluated by Kubernetes `failurePolicy` up there is not triggered,
  # it is another file that we are going to create having a `validationActions` that will decide what to do
  # is the `User` APIRequest to `CREATE` or `UPDATE` the `deployments` good to go or not
  paramKind:
    apiVersion: mister.w.rules/v1
    kind: VolumeNaruto
  validations:
    # expression using `CEL` language so comprise any operation like `.contains()`, `&&`, `==` ..etc.. see doc...
    #- expression: "object.spec.replicas <= object.spec.inventedfield"
      # in the doc you can specify some limited reasons otherwise put nothing and it will default to kubernetes ones
      #reason: Invalid
      # we are not going to use, but a message could also be entered, a text that you want this can be custom and also accepts arguments using `$(ARGUMENT)`
      # messages: ...
    # so keyword `object` is used to reference the resource created by user fields concerned in this policy
    # the keyword `params` is used to reference the field used in our custom `CEL` compliant resource
    - expression: "object.metadata.annotations['creditizens-vip-friends'].contains(params.soundRules)"
```

- `ValidatingAdmissionPolicyBinding`
(cat validating-admission-policy-bindings-mangakissa.yaml )
```yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: "volume-naruto-policy-binding.creditizens.com"
spec:
  # this field is referencing the `ValidatingAdmissionPolicy`: one policy to one binding
  policyName: "volume-naruto-policy.creditizens.com"
  # this would be actioned if the `expression` in the conterpart admission policy can be evaluated by Kubernates
  # actions can be `Deny`(APIRequest rejected) , `Warn`(APIRequest can pass with a warning),
  # `Deny + Audit` (Rejected with event written), `Warn + Audit` (Can Pass with event written), `Audit` can't be used alone
  validationActions: ["Deny"]
  # here the resource made available to check the expression in `ValidatingAdmissionPolicy` conterpart need to be matching this selector
  # so not all deployments will be checked, only the ones in any namespace having the label `location=shibuya-level-5`
  # therefore, the is what is checked first and only when this is satisfied the Admission policy check starts to be triggered and pass check those rules...
  # now we are providing the reference of the config file that is going to be used as reference in the `validations.expression`
  paramRef:
    name: "watch.naruto.mister.w.com"
    namespace: "mangakissa-zone"
    # if the external resource reference is not there anymore it will deny any APIRequest
    parameterNotFoundAction: "Deny"
  matchResources:
    namespaceSelector:
      matchLabels:
        location: shibuya-level-5
        # location: ometesando-level-2
```
Then just create deployment yaml files to play with annotations changing the `ValidatingAdmissionPolicy` `validation.expression`
also something that it is not in the documentation of Kubernetes is that using `paramRef` in `ValidatingAdmissionPolicyBinding` needs also in addition of `namespace` and `name`, a ` parameterNotFoundAction` ("Deny" or "Allow") taht would look if the referenced resource still exists. 

- exmaple deployment used with `annotations` and can change the `annotations` or comment it out
(cat mangakissa-admission-2-friends.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: mangakissa-admission-friend
  name: mangakissa-admission-2-friend
  namespace: mangakissa-zone
  annotations:
    creditizens-vip-friends: "naruto no sound"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mangakissa-admission-friend
  template:
    metadata:
      labels:
        app: mangakissa-admission-friend
    spec:
      containers:
      - image: nginx
        name: nginx
```
