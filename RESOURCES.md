# Resources

Primary sources used across the course, grouped by topic. Each chapter also lists the exact pages it relies on in its own Sources section.

## Azure basics (not taught in this course)

- [Microsoft Learn: Azure Fundamentals learning path](https://learn.microsoft.com/training/paths/az-900-describe-cloud-concepts/). Use it if subscriptions, resource groups or regions are new to you.
- [Install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli). Needed on your own computer before chapter 0.
- [Azure Retail Prices API](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices). The source of every price quoted in the course.

## Cost and guardrails

- [Azure spending limit](https://learn.microsoft.com/azure/cost-management-billing/manage/spending-limit). What happens when a credit-based subscription runs out of credit.
- [Monthly Azure credit for Visual Studio subscribers](https://azure.microsoft.com/pricing/member-offers/credit-for-visual-studio-subscribers/). Credit amounts, lower default quotas and unavailable regions.
- [Create and manage budgets](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets). Actual and forecast alerts, and how often budgets are evaluated.
- [States and billing status of Azure virtual machines](https://learn.microsoft.com/azure/virtual-machines/states-billing). Why "stopped" and "deallocated" are billed differently.

## Containers

- [Docker overview](https://docs.docker.com/get-started/docker-overview/). Images, containers and registries.
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/). Every instruction used in chapter 1.
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/) and [build cache](https://docs.docker.com/build/cache/). How to keep images small and builds fast.
- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/). How the lab VM gets Docker.
- [Podman documentation](https://docs.podman.io/). The daemonless container engine you meet again with OpenShift in chapter 7.
- [Open Container Initiative image specification](https://github.com/opencontainers/image-spec). The standard image format that Docker, Podman, Kubernetes and OpenShift all share.
- [Azure Container Registry documentation](https://learn.microsoft.com/azure/container-registry/). Push and pull images, service tiers and authentication.
- [Use a managed identity to authenticate to Azure Container Registry](https://learn.microsoft.com/azure/container-registry/container-registry-authentication-managed-identity). How the lab VM signs in without a password.

## Kubernetes

- [Kubernetes documentation](https://kubernetes.io/docs/home/). Concepts, tasks and reference.
- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/). Control plane, nodes and kubelet.
- [Kubernetes object management](https://kubernetes.io/docs/concepts/overview/working-with-objects/object-management/). Imperative commands compared with declarative configuration.
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) and [Services](https://kubernetes.io/docs/concepts/services-networking/service/). The two objects at the heart of chapter 2.
- [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/). Commands worth keeping open in a tab.
- [kind documentation](https://kind.sigs.k8s.io/). Local Kubernetes clusters in containers, used in chapters 2 to 5.

## OpenShift outside Azure (Red Hat)

- [OpenShift and Kubernetes: what's the difference?](https://www.redhat.com/en/blog/openshift-and-kubernetes-whats-difference) Kubernetes as the kernel, OpenShift as the distribution, OKD as the community upstream. Use it for the mental model of where OpenShift sits.
- [Usage of oc and kubectl commands](https://docs.redhat.com/en/documentation/openshift_container_platform/4.1/html/cli_reference/usage-oc-kubectl). Why kubectl works on OpenShift and what `oc` adds. The page found is an old version: check the latest version before quoting details.
- [OpenShift Container Platform architecture](https://docs.redhat.com/en/documentation/openshift_container_platform/4.5/html-single/architecture/index). RHCOS, CRI-O, operators that manage the platform, OperatorHub. Old version found: use the latest docs for anything version-sensitive.
- [Adapting Docker and Kubernetes containers to run on OpenShift](https://developers.redhat.com/blog/2020/10/26/adapting-docker-and-kubernetes-containers-to-run-on-red-hat-openshift-container-platform). Arbitrary user IDs and ports above 1023. Written in 2020: check it against current documentation in chapter 7.
- [Developer Sandbox for Red Hat OpenShift](https://developers.redhat.com/developer-sandbox). Free shared OpenShift cluster with a Red Hat account, used in chapter 7.

## Azure Red Hat OpenShift (Microsoft Learn)

- [What is Azure Red Hat OpenShift?](https://learn.microsoft.com/azure/openshift/intro-openshift) Jointly engineered and operated by Microsoft and Red Hat, two architectures (standard and hosted control planes). Use it for the service definition.
- [Responsibility matrix (standard architecture)](https://learn.microsoft.com/azure/openshift/responsibility-matrix). Who owns what between the customer, Microsoft and Red Hat.
- [Support policy (standard architecture)](https://learn.microsoft.com/azure/openshift/support-policies-v4). Hard rules: 3 control plane and 3 worker nodes minimum, 250 workers maximum, supported VM sizes, operators that must stay managed.
- [Service definitions](https://learn.microsoft.com/azure/openshift/openshift-service-definitions). Regions, node counts and what the customer pays for.
- [Quickstart: create a cluster](https://learn.microsoft.com/azure/openshift/create-cluster). Prerequisites: 44 cores at install time, resource providers, permissions, optional pull secret.
- [Azure Red Hat OpenShift pricing](https://azure.microsoft.com/pricing/details/openshift/). Licence charged per worker vCPU on top of the VMs.
- [Network concepts](https://learn.microsoft.com/azure/openshift/concepts-networking). Load balancers, Private Link for site reliability engineering access, NSG, egress.
- [Understand managed identities in ARO](https://learn.microsoft.com/azure/openshift/howto-understand-managed-identities). One managed identity per core operator plus a cluster identity.
- [ARO with hosted control planes](https://learn.microsoft.com/azure/openshift/howto-create-hosted-node-pool). Node pools and `az aro hcp`. Preview status may change.
- [Training module: Introduction to Azure Red Hat OpenShift](https://learn.microsoft.com/training/modules/introduction-to-azure-red-hat-openshift/). Short beginner module with an assessment.

## ARO compared with AKS

- [Comparing AKS with other Azure container options](https://learn.microsoft.com/azure/aks/compare-container-options-with-aks). Positions ARO as the fit when the organisation already uses OpenShift.
- [Choose an Azure container service](https://learn.microsoft.com/azure/architecture/guide/choose-azure-container-service). Service models, AKS Standard and AKS Automatic.
- [Choose a compute option for microservices](https://learn.microsoft.com/azure/architecture/microservices/design/compute-options). AKS offers Dapr and KEDA as managed add-ons, while on OpenShift you install and maintain them yourself.

## Gaps

- Microsoft Learn has no official side-by-side table of ARO and AKS. Chapter 10 builds one from the responsibility matrix, the support policy and the AKS documentation.
- Current Red Hat architecture pages are needed to replace the old 4.x links above before chapter 7 is written.
- Communities of ARO practitioners have not been researched yet.
