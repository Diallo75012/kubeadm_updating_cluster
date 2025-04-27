# Cronnobs
source: (doc cronjobs)[https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#schedule-syntax]

**Important from doc**: 
  - "Jobs that you define should be idempotent", meaning consistent result even if it runs multiple times. So running it would have same effects everytime.
  - `controller` stop running `cronjobs` when it counts 100 misses. Missed can be concurrent job not allowed to run together as set to `forbid` plus misses `jobs` in general and the `startingDeadlineSeconds` is also in the matrix for failed jobs if it set to a value greater than zero.

The name of the `cronjob` will be used by `controller` plane to `.metadata.name` the pod running that job.
- imperative commands:
```bash
# get list of jobs
k get jobs
# get logs from job
k logs job/<jobname-5489455....>
# can patch job to suspend its executions
kubectl patch cronjob/<name_of_cronjob> -p '{"spec": {"suspend": true}}'
# exec in a cronjob pod 
kubectl exec --stdin --tty job/<pod_name_123...> -- sh
```

- example job yaml file
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-junko
spec:
  # run every 5mn, kubernetes can't set per seconds schedule, so you need to set at least a minutes
  schedule: "*/5 * * * *"

  # can use time zone: see documentation
  # timeZone: "Etc/UTC"

  # this will tell how long before the job starts running when it is time for it run on the above `schedule` and misses that time
  # it will allow the job to run. eg. job have to run once a day, if it misses because for example `concurrency` is not allowed you can set this field to few hours in seconds to allow it to start anytime again between the missed schedule time and this `startingDeadlineSeconds` time (after it)
  # startingDeadlineSeconds: 10  # do not set it under 10 seconds as the job won't be scheduled as `cronjob controller` checks every 10 seconds

  # this can be `forbid` telling it to not run concurrently with other jobs or `Allow` the default which allow concurrency
  # another one is `Replace` would just run one job at a time so 'No Concurrency'
  # but when it can run would stop the running job to start a new one even if the previous is not completed yet. so would not wait for previous job to finish.
  # this field tales into consideration (when used as optional) the field `startingDeadlineSeconds`
  # concurrencyPolicy: Forbid

  # can also re-apply this Cronjob to patch it and suspend the job. has effect on subsequent job scheduled which will be suspended and not run
  # but the current running job will not be interupted
  # suspend: true

  # this indicated how much logs to keep. default to 3 for `success` one and to 1 for `failure` one.
  # can be set to `0` to not keep any logs. but better to put a number for easy debugging
  # successfulJobsHistoryLimit: 10
  # failedJobsHistoryLimit: 3

  # `backoffLimit` is how many times kubernetes will try to run the `cronjob` if attempts fail to run it before killing iti
  # backoffLimit: 10

  jobTemplate:
    spec:
      # can also use TTL which is going to to delete the job and logs
      # even if it didn't execute or executed not the full amount of times (success/failure) after this `TTL` time
      # so here no stale job staying on the cluster and prevents using manual `kubectl delete job <this cronjob>`
      # ttlSecondsAfterFinished: 600
      template:
        metadata:
          # can also label the cronjob
          labels:
            cron-job-location: shibuya
        spec:
          containers:
          - name: hello-junko
            image: busybox:1.36.1
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello Junko! from Kubernetes Shibuya!
          restartPolicy: OnFailure

```

## so each job will be a pod so need to limit that
```bash
k get jobs -o wide
NAME                       COMPLETIONS   DURATION   AGE     CONTAINERS   IMAGES           SELECTOR
shibuya-cronjob-29087591   1/1           3s         3m32s   hello        busybox:1.36.1   batch.kubernetes.io/controller-uid=c81bf556-cd53-4ff0-902f-779cf250cce4
shibuya-cronjob-29087592   1/1           3s         2m32s   hello        busybox:1.36.1   batch.kubernetes.io/controller-uid=56136263-5925-4749-9e33-a51ee73b4be1
shibuya-cronjob-29087593   1/1           4s         92s     hello        busybox:1.36.1   batch.kubernetes.io/controller-uid=bb41dede-e96e-4996-aedd-06ff1b395be2
shibuya-cronjob-29087594   1/1           4s         32s     hello        busybox:1.36.1   batch.kubernetes.io/controller-uid=97596346-1dd5-4de1-adaf-a7d72e44e975
```

so might be interesting to use the optional field `ttlSecondsAfterFinished: <sometime>` so the pod will be deleted automatically after finishing and some `TTL` time.

## Helm way to install cronjob in cluster
source: (helm doc)[https://helm.sh/docs/intro/install/]
- easiest way with latest version of helm fetched and installed
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
- apt repo updated way
```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

- then create a helm chart, delete the templates present theri by default, and put your `cronjob` yaml file there.
```bash
helm create shibuya-cronjob
cd shibuya-cronjob
# delete all default templates
sudo rm -r templates/*
# create your cronjob yaml file
nano templates/my_cronjob_shibuya.yaml
# update the chart information
nano Chart.yaml
# inside
apiVersion: v2
name: shibuya-cronjob
description: “cronjob shibuya using Helm for versioning and easy change”
type: application
version: 1.1.0
# apply to cluster and you will have the `shibuya-cronjob.yaml` handled by `Helm` like for any applications Helm would do normally
helm install shibuya-cronjob .
# alternatively could even push this Helm chart to your repository on Helm or other
heml push...
```

## `schedule` part in cronjob explanation
source: (kubernetes doc schedule cronjob)[https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#schedule-syntax]
```markdown
# ┌─ minute (0 - 59)
# │ ┌─ hour (0 - 23)
# │ │ ┌─ day of the month (1 - 31)
# │ │ │ ┌─ month (1 - 12)
# │ │ │ │ ┌─ day of the week (0 - 6) (Sunday to Saturday) OR sun, mon, tue, wed, thu, fri, sat
# │ │ │ │ │
# │ │ │ │ │ 
# │ │ │ │ │
# * * * * *
```

## scenario 
use `Helm` and a cronjob to run every minutes to write a sentence in a volume that would be fetched by another pod, or maybe a cronjob to update a configmap so that we would see in internet browser that the message changes in the page. something simple like showing `date` with `hour` for example.

So here have decided to run an example using some concepts seen before, i could have used persisent volumes but will just use `hostPath` shared volume on a node, `affinity` to have the pod on a specific node and `cronjob` with also affinity to have access to that node volume. `nginx` hatml page would be changed with a message showing date and time of an event `every minutes`, a `ttlSecondsAfterFinished` option is used in the `cronjob` for the stale job to be deleted after a certain time.
- `cat templates/shibuya-cronjob.yaml`
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: shibuya-cronjob
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 120
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.36.1
            #imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - echo "<h1 style='display:flex;flex-direction:row;align-items:center;justify-content:center;color:darkblue;'>Junko will be here on the $(date | awk '{print $2,$3}') at $(date | awk '{print $4}')</h1>" > "/tmp/index.html"
            # - echo "junko will be here on the $(date)" > "/tmp/index.html"
            volumeMounts:
            - name: shared-volume
              mountPath: "/tmp"
          restartPolicy: OnFailure
          volumes:
          - name: shared-volume
            hostPath:
              path: "/tmp"
              #type: DirectoryOrCreate

          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: location
                    operator: In
                    values:
                    - shibuya
```

- `cat templates/test_nginx.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: test-nginx
  name: test-nginx
spec:
  containers:
  - image: nginx
    name: test-nginx
    volumeMounts:
    - name: shared-volume
      mountPath: "/usr/share/nginx/html"

  volumes:
  - name: shared-volume
    hostPath:
      path: "/tmp"
      #type: DirectoryOrCreate

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: location
            operator: In
            values:
            - shibuya
```
