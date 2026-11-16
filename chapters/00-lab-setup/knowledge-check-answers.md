# Chapter 0 knowledge check: answers

Back to the [chapter](README.md#knowledge-check).

## 1. A VM stopped from inside

Answer: B. Compute, the disk and the public IP address.

Shutting the operating system down leaves the VM in the Stopped state: Azure keeps the hardware reserved, so compute is still billed. Only a deallocation through Azure (portal, `az vm deallocate`, auto-shutdown) stops the compute charge. The disk and the static public IP address are billed in every state. See [States and billing of Azure VMs](https://learn.microsoft.com/azure/virtual-machines/states-billing).

## 2. A budget at 100%

Answer: C. It sends an e-mail to the budget contacts and changes nothing else.

Budgets only notify. Resources keep running and consumption is not stopped. The spending limit is what stops services, and it works on the credit, not on the budget. See [Create and manage budgets](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets).

## 3. Credit spent on the 20th

Answer: B. Your services are disabled until the next billing period, and VMs are stopped and deallocated.

With the spending limit on, Azure disables the services for the rest of the billing period and re-enables the subscription at the start of the next one. Nothing is charged to a card, and nothing is deleted. See [Azure spending limit](https://learn.microsoft.com/azure/cost-management-billing/manage/spending-limit).

## 4. After teardown stop

Answer: B. The OS disk and the static public IP address.

`teardown.sh stop` deallocates the VM, which stops the compute charge only. The disk keeps your work and is billed per month, and the static public IP address is billed per hour as long as it exists. A budget has no cost. Only `teardown.sh destroy` removes the disk and the IP address.

## 5. The managed identity of the lab VM

Answer: A. So that scripts on the VM can call Azure without storing a password or token on the VM.

A managed identity is an identity in Microsoft Entra ID that belongs to the VM. Scripts on the VM sign in with `az login --identity` and Azure hands them a short-lived token. It has nothing to do with SSH sign-in, internet access or budget alerts. See [Managed identities for Azure resources](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview).
