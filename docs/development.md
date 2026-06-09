# Development Guide

## Prerequisites

- Docker
- Access to a Kubernetes cluster (kubeconfig file)
- (Optional) GitHub CLI (`gh`) for secret management

## Local Build

```bash
export KUBECONFIG_B64=$(cat ~/.kube/config | base64 -w0)
docker build --build-arg KUBECONFIG_B64="$KUBECONFIG_B64" -t dockerized-deployment .
```

Build without a Kubeconfig (image will work, but no default cluster):

```bash
docker build -t dockerized-deployment .
```

## Testing

### Quick smoke test

```bash
docker run --rm dockerized-deployment kubectl version --client
docker run --rm dockerized-deployment helm version
```

### Cluster interaction

```bash
docker run --rm dockerized-deployment kubectl get nodes
docker run --rm dockerized-deployment helm list -A
```

### Test script

The `scripts/test-container.sh` script pulls the published GHCR image and runs cluster queries.

## CI/CD Pipeline

Pushes to `main` trigger `.github/workflows/build-and-push.yml`:

1. Checkout
2. Set up Docker Buildx
3. Log in to GHCR with `GITHUB_TOKEN`
4. Build and push with tags: `latest` and `<git-sha>`
5. GitHub Actions cache is used for faster rebuilds

## Setting up the Kubeconfig Secret

Run the helper script from a machine with SSH access to the K3s host:

```bash
SSH_HOST=my-k3s.example.com SSH_USER=root ./scripts/set-kubeconfig-secret.sh
```

This will:
1. SSH into the host and read `/etc/rancher/k3s/k3s.yaml`
2. Update the server URL to `https://<host>:6443`
3. Base64-encode the YAML
4. Store it as GitHub secret `KUBECONFIG_B64`
5. Save a local copy to `.kubeconfig.b64` (gitignored)

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) for guidelines.
