# Chapter 2 knowledge check: answers

Back to the [chapter](README.md#knowledge-check).

## 1. Where the desired state lives

Answer: B. etcd.

etcd is the database of the control plane, and the API server is the only component that reads and writes it. The kubelet runs pods on a node, the scheduler places pods on nodes, and kube-proxy routes Service traffic. See [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/).

## 2. A deleted pod

Answer: C. Its ReplicaSet creates a new pod with a new name, to get back to 5.

The ReplicaSet counts the pods that match its selector and creates a new one as soon as the count drops. Pods are never repaired or recreated with the same identity: the new pod has a new name and a new IP address. The other pods are not touched. See [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/).

## 3. NodePort, `port` and `targetPort`

Answer: B. To port 8080 of one of the selected pods.

The node port (30080) is the entry point on every node, `port` (80) is the port of the Service inside the cluster, and `targetPort` (8080) is the port of the containers. The Service sends each request to one ready pod among those its selector matches. See [Service](https://kubernetes.io/docs/concepts/services-networking/service/).

## 4. After kubectl rollout undo

Answer: A. Your YAML file still says 2.0.0, so the next `kubectl apply` brings it back unless you change the file.

`rollout undo` changes the cluster, not your files. The ReplicaSet of 2.0.0 is kept, scaled to zero, for a later rollback. The Deployment moves to a new revision (3 in the lab), not back to 1, and the pods of 1.0.0 are new pods with new names. See [Rolling back a Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment).

## 5. Why NodePort in the lab

Answer: C. A `NodePort` Service is reachable from outside the cluster, here from the lab VM, without any extra component.

A `ClusterIP` Service selects pods just as well, but is only reachable from inside the cluster. `NodePort` is not faster, and kind supports both types. Chapter 3 covers better ways to expose an app. See [Service types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types).
