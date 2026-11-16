# Mission

## Goal

Take a learner who knows basic Azure and nothing about containers to the point where they can run applications on Kubernetes, operate an Azure Red Hat OpenShift (ARO) cluster, and argue when ARO or Azure Kubernetes Service (AKS) is the better fit for a large enterprise workload.

Every chapter is hands-on. The learner works on their own Azure subscription, from a small Linux lab VM, the way a platform team works, and checks their own work with a validation script.

## Learner profile

- Knows the Azure basics: the portal, subscriptions, resource groups, `az login`, and what a virtual network is.
- Has never built a container image and has never used Kubernetes.
- Is comfortable typing commands in a terminal and editing text files, but is not expected to write application code.
- Has an Azure subscription with a monthly credit of about 130 EUR, typically the credit included in a Visual Studio subscription, with the spending limit on.
- Has a computer with the Azure CLI, Git and an SSH client. On Windows, Git for Windows provides the Git Bash terminal used to run the scripts.

The course does not teach Azure itself. Where an Azure basic is needed, it links to Microsoft Learn.

## Success criteria

The course has four parts. A learner who finishes a part can do the following without a tutorial open.

### Part 1, foundations (chapters 0 to 2)

- Explain how a credit-based subscription is billed, what stops the spending, and which lab resources still cost money when the VM is stopped.
- Create and destroy the lab environment from code, and read a readiness report.
- Write a Dockerfile for a small web app, build a small non-root image, run it, read its logs and push it to Azure Container Registry.
- Describe the parts of a Kubernetes cluster, deploy an app declaratively with a Deployment and a Service, scale it, roll out a new version and roll it back.

### Part 2, Kubernetes in practice (chapters 3 to 5)

- Configure an app with ConfigMaps and Secrets, give it storage, and expose it outside the cluster.
- Control who can do what in a cluster with namespaces and role-based access control, and run workloads with a restricted security context.
- Install and upgrade software with Helm, and explain what an operator does.

### Part 3, managed platforms (chapters 6 and 7)

- Create an AKS cluster, deploy the sample app to it from Azure Container Registry, and delete the cluster cleanly.
- Deploy the sample app to OpenShift on the Red Hat Developer Sandbox with `oc`, and explain what OpenShift adds to Kubernetes (projects, routes, security context constraints, the web console, operators that manage the platform).

### Part 4, Azure Red Hat OpenShift (chapters 8 to 10)

- Explain the ARO architecture and the shared responsibility between Microsoft, Red Hat and the customer.
- Check the prerequisites, create an ARO cluster, deploy the sample app, and delete the cluster in the same session.
- Perform day-two tasks on ARO: access, monitoring, upgrades and scaling.
- Write a design note that compares ARO and AKS for a large enterprise workload and lists what to check before choosing.

## Out of scope

- Azure fundamentals (covered by Microsoft Learn).
- Writing application code. The sample app is provided.
- Installing self-managed OpenShift (installer-provisioned or user-provisioned infrastructure).
- OpenShift Virtualization and OpenShift AI.
- Preparing for a certification exam.
- Production hardening beyond what each chapter states. The labs are built for learning on a small budget, not as production templates.
