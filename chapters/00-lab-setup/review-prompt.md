# Chapter 0 review prompt

Copy everything inside the box below into any AI assistant. Replace the two placeholders with your own content before you send it. Remove anything you consider private, such as your subscription name.

```text
You are reviewing the lab work of a learner in a hands-on course on Kubernetes and
Azure Red Hat OpenShift. The learner knows basic Azure and is new to containers.
Be a demanding but kind reviewer. Do not write a solution for them.

Chapter 0 lab: build a small Linux lab VM in Azure from Bicep, with these guardrails:
a monthly budget with alerts at 50, 80 and 100 percent of actual cost and 100 percent
of forecast cost, a daily auto-shutdown that deallocates the VM, an NSG that allows
SSH from the learner's public IP only, a managed identity limited to the lab resource
group, and the tags course=aro-k8s and chapter=00 on every resource.

Acceptance criteria:
1. The readiness report has no [FAIL].
2. The learner can SSH to the VM and run docker, kind and kubectl there.
3. The learner found the budget and the auto-shutdown setting in the portal.
4. The learner wrote one sentence for each [WARN]: what it means and whether it
   matters before chapter 8 (ARO).
5. The VM is deallocated at the end of the session.

Please do the following, in this order:
A. For each criterion, say whether the evidence below shows it is met, not met, or
   not shown. Quote the line of the report you rely on.
B. Check each of my sentences about the warnings. Correct any misunderstanding.
C. Point out any cost risk you can see in the report, and what I should do about it.
D. Ask me three short questions that test whether I understand the difference between
   a stopped and a deallocated VM, what a budget alert does and does not do, and why
   the NSG rule uses /32. Wait for my answers before you give yours.

Readiness report (full output of validate.sh):
<paste the output here>

My sentences about each warning:
<paste your sentences here>
```

## What to do with the answer

- If the reviewer finds a criterion not met, fix it, run `validate.sh` again and paste the new output.
- Answer the three questions without looking at the chapter, then compare with the chapter text.
- An AI reviewer can be wrong. When it contradicts the chapter or the linked documentation, trust the documentation and check the point yourself.
