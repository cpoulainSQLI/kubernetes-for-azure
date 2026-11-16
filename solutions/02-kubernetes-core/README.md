# Chapter 2 reference solution

Try the lab on your own first. Come here when you are stuck for more than 20 minutes, or after `validate.sh` passes, to compare approaches.

## Files

- [namespace.yaml](namespace.yaml) creates the `sample-app` namespace.
- [deployment.yaml](deployment.yaml) shows the final state: 5 replicas of version 1.0.0, with a readiness probe as the stretch goal.
- [service.yaml](service.yaml) exposes the pods on port 80 inside the cluster and on node port 30080.

## Commands, in order

Run them on the lab VM, in `~/work/02-kubernetes-core`, after chapter 2 setup.

```bash
# 1. Namespace, then the Deployment with 3 replicas (edit replicas: 3 in the file first).
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl -n sample-app rollout status deployment/sample-app
kubectl -n sample-app get pods -o wide --show-labels

# 2. Service.
kubectl apply -f service.yaml
kubectl -n sample-app get service,endpointslices
NODE_IP=$(kubectl get node aro-k8s-control-plane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
for i in 1 2 3 4 5; do curl -s "http://$NODE_IP:30080/"; done

# 3. Scale to 5: change replicas to 5 in deployment.yaml, then apply again.
kubectl apply -f deployment.yaml
kubectl -n sample-app get pods

# 4. Self-healing: delete one pod and watch a new one replace it.
kubectl -n sample-app delete pod "$(kubectl -n sample-app get pods -o name | head -n 1 | cut -d/ -f2)"
kubectl -n sample-app get pods --watch     # Ctrl+C to stop watching

# 5. Version 2.0.0: build it from the chapter 1 folder and load it into kind.
cd ~/work/01-containers/sample-app
docker build --build-arg VERSION=2.0.0 -t sample-app:2.0.0 .
kind load docker-image sample-app:2.0.0 --name aro-k8s
cd ~/work/02-kubernetes-core
# Change the image to sample-app:2.0.0 in deployment.yaml, then:
kubectl apply -f deployment.yaml
kubectl -n sample-app rollout status deployment/sample-app
kubectl -n sample-app rollout history deployment/sample-app

# 6. Roll back to the previous revision.
kubectl -n sample-app rollout undo deployment/sample-app
kubectl -n sample-app rollout status deployment/sample-app
kubectl -n sample-app rollout history deployment/sample-app
# Then put image: sample-app:1.0.0 back in deployment.yaml, so the file matches the cluster.
```

## Why these choices

- Every change goes through the YAML files and `kubectl apply`, so the files always describe what runs. The only exception is `kubectl rollout undo`, which is why step 6 ends by updating the file.
- The selector, the pod template labels and the Service selector all use `app.kubernetes.io/name: sample-app`, one of the recommended Kubernetes labels.
- The Service is of type `NodePort` so that you can reach it from the VM without any extra component. Chapter 3 replaces this with a better way to expose the app.
- `imagePullPolicy: IfNotPresent` makes it explicit that the image is never pulled from a registry. With a tag other than `latest`, it is also the default.
