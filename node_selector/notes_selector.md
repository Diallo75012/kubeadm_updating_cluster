# Personal notes and documenation to have an overview on selectors in Kubernetes (ChatGPT)

## Resources that uses `selector`
Resource Kind 		| Selector Field Location 		| Selector Format 		| Points To
Service 		| spec.selector 			| { key: value } 		| Pod labels
Deployment 		| spec.selector.matchLabels 		| matchLabels, matchExpressions | Pod template labels
ReplicaSet 		| spec.selector.matchLabels 		| matchLabels, matchExpressions | Pod template labels
StatefulSet 		| spec.selector.matchLabels 		| matchLabels, matchExpressions | Pod template labels
DaemonSet 		| spec.selector.matchLabels 		| matchLabels, matchExpressions | Pod template labels
Job 			| spec.selector.matchLabels (optional) 	| matchLabels, matchExpressions | Pod template labels
HorizontalPodAutoscaler | spec.scaleTargetRef (different) 	| Uses kind, name, apiVersion 	| A scalable resource (e.g. Deployment)
NetworkPolicy 		| spec.podSelector, namespaceSelector 	| matchLabels, matchExpressions | Pod or Namespace labels
ServiceMonitor (CRD) 	| spec.selector.matchLabels 		| matchLabels, matchExpressions | Service labels
PodDisruptionBudget 	| spec.selector.matchLabels 		| matchLabels, matchExpressions | Pod labels
PodAffinity 		| labelSelector.matchLabels 		| matchLabels, matchExpressions | Pod labels
VolumeAttachment 	| spec.nodeSelector 			| { key: value } 		| Node labels
Ingress (with class) 	| spec.ingressClassName 		| (Reference string) 		| IngressClass by name


## Types of `seletor` in `Kubernetes
Selector Type 		| YAML Field Name 		| Used In Resources 					| What It Selects
Label Selector 		| matchLabels 			| Most core resources (Deployments, Services) 		| Match exact key-value pairs on target
Label Selector (Expr) 	| matchExpressions 		| Advanced in Deployments, StatefulSets, etc. 		| Complex matching with operators
Namespace Selector 	| namespaceSelector.matchLabels | NetworkPolicy, ValidatingAdmissionPolicyBinding 	| Match Namespace labels
Node Selector 		| nodeSelector 			| Pod.spec, DaemonSet.spec.template.spec 		| Match node labels
Node Affinity 		| requiredDuringScheduling... 	| Pod.spec.affinity.nodeAffinity 			| Schedule Pods on matching Nodes
Pod Affinity 		| podAffinity 			| Pod.spec.affinity.podAffinity 			| Schedule Pods close to matching Pods
Pod AntiAffinity 	| podAntiAffinity 		| Pod.spec.affinity.podAntiAffinity 			| Schedule Pods away from matching Pods
Field Selector 		| CLI (e.g. kubectl get pod --field-selector=...) 	| Not in YAML, CLI-only 	| Filter by field (e.g. status.phase)
Owner References 	| metadata.ownerReferences 	| All objects 						| Reference parent resource

# example `matchExpressions`
Operator 	| Description
In 		| Key is in the list of values
NotIn 		| Key is NOT in the list
Exists 		| Key exists
DoesNotExist 	| Key does not exist
