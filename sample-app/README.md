# Sample app

A small web application written in Go, using only the Go standard library. You build it into a container image in chapter 1, deploy it to Kubernetes in chapter 2 and reuse it in later chapters.

You do not need to know Go. You only need to know how the app behaves and how to build it.

## What it does

| Request | Answer |
| --- | --- |
| `GET /healthz` | Status 200 with the text `ok`. Used by health checks. |
| `GET /` | Status 200 with JSON: the app name, its version and the host name it runs on. |
| Anything else | Status 404. |

Example answer from `GET /`:

```json
{"app":"sample-app","version":"1.0.0","hostname":"5f2c9a1b7d3e"}
```

Inside a container, the host name is the container ID. Inside Kubernetes, it is the pod name. This makes it easy to see which copy of the app answered.

The app writes one log line per request to standard output and stops cleanly when it receives the `SIGTERM` signal.

## Settings

| Setting | How to set it | Default |
| --- | --- | --- |
| Listening port | `PORT` environment variable | `8080` |
| Version shown by `GET /` | Build flag `-ldflags "-X main.version=<version>"` | `dev` |

The app never needs to write to disk and never needs root privileges, so it runs as any non-root user.

## Build it without containers (optional)

If Go is installed on a machine, these commands build and test the app. The lab VM does not need Go, because the build happens inside a container in chapter 1.

```bash
go test ./...
CGO_ENABLED=0 go build -ldflags "-X main.version=1.0.0" -o sample-app .
./sample-app
```

`CGO_ENABLED=0` produces a static binary, which means the binary does not depend on any library from the operating system it runs on.

## Files

- `main.go` is the application.
- `main_test.go` holds three small tests.
- `go.mod` declares the Go module. The app has no third-party dependencies.

There is no `Dockerfile` here on purpose. Writing it is your task in chapter 1.
