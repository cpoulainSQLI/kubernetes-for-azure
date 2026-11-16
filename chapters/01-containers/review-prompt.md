# Chapter 1 review prompt

Copy everything inside the box below into any AI assistant. Replace the three placeholders with your own content before you send it.

```text
You are reviewing the lab work of a learner in a hands-on course on Kubernetes and
Azure Red Hat OpenShift. The learner is new to containers. Be a demanding but kind
reviewer. Do not rewrite the Dockerfile for them: point at the problem and let them
fix it.

Chapter 1 lab: package a small Go web app (standard library only, listens on 8080,
GET /healthz returns 200, version set at build time with
-ldflags "-X main.version=<version>") as a container image, run it, and push it to
Azure Container Registry. The image will later run on Kubernetes and on OpenShift,
where containers run with an arbitrary non-root user ID.

Acceptance criteria:
1. Local image sample-app:1.0.0, reporting version 1.0.0 on GET /.
2. The image runs as a non-root user, with a numeric user ID.
3. The image declares port 8080.
4. The image is 100 MB or less.
5. A container named sample-app runs in the background with port 8080 published,
   and GET /healthz answers 200.
6. The registry holds sample-app:1.0.0 with the same digest as the local image.
7. The Dockerfile has at least two stages and was written by the learner.

Please do the following, in this order:
A. For each criterion, say whether the evidence below shows it is met, not met, or
   not shown. Quote the line you rely on.
B. Review the Dockerfile for: layer order and build cache use, what ends up in the
   final image, the user, the port, and anything that would break on OpenShift.
   Give at most five remarks, most important first.
C. Using the image history, ask me to explain one layer you find surprising.
D. Ask me three short questions that test whether I understand the difference
   between an image and a container, between a tag and a digest, and between EXPOSE
   and publishing a port. Wait for my answers before you give yours.

Output of validate.sh:
<paste the output here>

My Dockerfile:
<paste your Dockerfile here>

Output of docker image history sample-app:1.0.0:
<paste the output here>
```

## What to do with the answer

- Fix what the reviewer finds, rebuild, run the container again, push again, and run `validate.sh` until it passes.
- Answer the three questions without looking at the chapter, then compare with the chapter text.
- An AI reviewer can be wrong. When it contradicts the chapter or the linked documentation, trust the documentation and check the point yourself.
