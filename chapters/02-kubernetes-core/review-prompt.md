# Chapter 2 review prompt

Copy everything inside the box below into any AI assistant. Replace the four placeholders with your own content before you send it.

```text
You are reviewing the lab work of a learner in a hands-on course on Kubernetes and
Azure Red Hat OpenShift. The learner is new to Kubernetes. Be a demanding but kind
reviewer. Do not rewrite the YAML files for them: point at the problem and let them
fix it.

Chapter 2 lab, on a kind cluster (1 control plane, 2 workers): in namespace
sample-app, a Deployment sample-app runs the image sample-app:1.0.0 (a web app on
port 8080 with GET /healthz), selected by the label app.kubernetes.io/name=sample-app.
A NodePort Service sample-app exposes port 80 to container port 8080, on node port
30080. The learner scaled from 3 to 5 replicas, deleted a pod to watch self-healing,
rolled out 2.0.0, then rolled back to 1.0.0 with kubectl rollout undo. Every change
must go through YAML files and kubectl apply, and the files must match the cluster at
the end. A readiness probe on /healthz is an optional stretch goal.

Please do the following, in this order:
A. List the requirements above that the evidence shows as met, not met or not
   shown. Quote the line you rely on.
B. Review the YAML files for: selector and label consistency, ports, whether the
   files match the final state of the cluster (image 1.0.0, 5 replicas), and what
   would happen if I ran kubectl apply on them now. Give at most five remarks, most
   important first.
C. Read my rollout history and my notes on the deleted pod. Correct anything I got
   wrong about which component did what.
D. Ask me three short questions that test whether I understand the difference
   between a Deployment and a ReplicaSet, how a Service finds its pods, and why
   kubectl rollout undo can be undone by the next kubectl apply. Wait for my answers
   before you give yours.

Output of validate.sh:
<paste the output here>

My YAML files (namespace, Deployment, Service):
<paste your files here>

Output of kubectl -n sample-app rollout history deployment/sample-app:
<paste the output here>

My notes from deleting a pod (names before and after, what I think happened):
<paste your notes here>
```

## What to do with the answer

- Fix what the reviewer finds, apply your files again and run `validate.sh` until it passes.
- Answer the three questions without looking at the chapter, then compare with the chapter text.
- An AI reviewer can be wrong. When it contradicts the chapter or the linked documentation, trust the documentation and check the point yourself.
