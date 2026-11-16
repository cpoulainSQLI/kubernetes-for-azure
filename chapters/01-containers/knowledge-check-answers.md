# Chapter 1 knowledge check: answers

Back to the [chapter](README.md#knowledge-check).

## 1. What EXPOSE does

Answer: C. It records that the app listens on 8080, as documentation and metadata.

`EXPOSE` adds the port to the image metadata, where tools and people can read it. It does not publish the port on the host, it does not touch any firewall, and it does not change the port the app listens on. Publishing happens at run time with `-p`. See the [Dockerfile reference](https://docs.docker.com/reference/dockerfile/#expose).

## 2. A reference that never moves

Answer: C. `sample-app@sha256:<digest>`.

A digest is computed from the content of the image, so it always designates the same bytes. Tags, including `latest` and `1.0.0`, are labels that can be moved to another image. A name without a tag means `latest`. See [Pull an image by digest](https://docs.docker.com/reference/cli/docker/image/pull/#pull-an-image-by-digest-immutable-identifier).

## 3. What a two-stage build keeps

Answer: B. The base image of the last stage plus the files copied into it.

Only the last stage becomes the image. Earlier stages are used during the build and then discarded, unless the last stage copies files from them with `COPY --from`. See [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/).

## 4. Credentials for docker push on the lab VM

Answer: B. From `az acr login`, which uses the token of the identity the Azure CLI is signed in with.

On the lab VM the Azure CLI is signed in with the VM's managed identity. `az acr login` turns that sign-in into a registry token for Docker. The admin account is disabled, `.env` never holds a password, and SSH keys have nothing to do with registries. Even a registry in your own subscription requires authentication. See [Authenticate with a managed identity](https://learn.microsoft.com/azure/container-registry/container-registry-authentication-managed-identity).

## 5. A numeric user ID

Answer: B. A numeric ID lets Kubernetes verify that the container does not run as root, and needs no user database in the image.

User names are allowed in a Dockerfile, but a name has to be looked up in the image's user database, which `scratch` does not have, and Kubernetes refuses to start a `runAsNonRoot` container whose image user is a name, because it cannot verify it. The ID does not change the image size, and OpenShift picks its own arbitrary ID anyway. See [Configure a security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).
