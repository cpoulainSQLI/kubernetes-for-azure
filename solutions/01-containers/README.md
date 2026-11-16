# Chapter 1 reference solution

Try the lab on your own first. Come here when you are stuck for more than 20 minutes, or after `validate.sh` passes, to compare approaches.

There is more than one correct solution. A Dockerfile that uses another small base image, such as a distroless image, is just as valid if the validation passes.

## Files

- [Dockerfile](Dockerfile) is a two-stage build: a Go toolchain image compiles the app, then an empty `scratch` image receives only the binary.

## Commands, in order

Run them on the lab VM, in `~/work/01-containers/sample-app`, after copying the Dockerfile there.

```bash
# Build and tag the image, passing the version to the build.
docker build --build-arg VERSION=1.0.0 -t sample-app:1.0.0 .

# Inspect what you built.
docker image ls sample-app
docker image history sample-app:1.0.0
docker image inspect --format '{{.Config.User}} {{json .Config.ExposedPorts}}' sample-app:1.0.0

# Run it in the background and test it.
docker run -d --name sample-app -p 8080:8080 sample-app:1.0.0
curl -i http://localhost:8080/healthz
curl http://localhost:8080/
docker logs sample-app

# Push it to the chapter registry.
REGISTRY=$(az acr list --resource-group "${PREFIX:-arok8s}-lab-rg" --query "[?tags.chapter=='01'].loginServer | [0]" -o tsv)
az acr login --name "${REGISTRY%%.*}"
docker tag sample-app:1.0.0 "$REGISTRY/sample-app:1.0.0"
docker push "$REGISTRY/sample-app:1.0.0"
az acr repository show-tags --name "${REGISTRY%%.*}" --repository sample-app -o table
```

`${REGISTRY%%.*}` keeps the part of the login server before the first dot, which is the registry name.

## Why these choices

- Two stages keep the Go toolchain (several hundred MB) out of the final image. The final image only holds the binary.
- `COPY go.mod` comes before `COPY *.go` so that a change in the code does not invalidate the layer that depends only on the module file. With no third-party dependencies the gain is small here, but the habit matters for real projects.
- `USER 65532:65532` uses numbers, not a name, because `scratch` has no user database and Kubernetes checks numeric IDs.
- `EXPOSE 8080` documents the port. Publishing still happens with `-p` at run time.
