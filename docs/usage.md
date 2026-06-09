# Usage Guide

## Overview

The `dockerized-deployment` image provides **kubectl** and **Helm** in a slim Alpine container, designed for CI/CD pipelines. A Kubeconfig can be baked into the image at build time or injected at runtime.

## Using in GitHub Actions

### Full job in container (recommended)

The entire job runs inside the image. The default Kubeconfig (baked at build time) is used automatically.

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - name: Deploy with Helm
        run: |
          helm repo add myrepo https://charts.example.com
          helm upgrade --install myapp myrepo/myapp \
            --namespace staging \
            --set image.tag="${{ github.sha }}"
```

> Swap the tag to `production` (or another stage) to target the respective cluster.

### Override Kubeconfig at runtime

Set `KUBECONFIG_B64` as an environment variable in the job to use a different Kubeconfig than the one baked into the image.

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
      env:
        KUBECONFIG_B64: ${{ secrets.STAGING_KUBECONFIG }}
    steps:
      - name: Deploy to staging
        run: |
          helm upgrade --install myapp myrepo/myapp -n staging
```

### Single step with docker run

Use the image for a single step without `container:`:

```yaml
- name: Deploy with Helm
  run: |
    echo "${{ secrets.KUBECONFIG_B64 }}" | base64 -d > kubeconfig
    docker run --rm -e KUBECONFIG_B64="${{ secrets.KUBECONFIG_B64 }}" \
      -v "$PWD:/workspace" -w /workspace \
      ghcr.io/projekt-construct-x/dockerized-deployment:staging \
      sh -c '
        helm repo add myrepo https://charts.example.com
        helm upgrade --install myapp myrepo/myapp -n staging
      '
```

### Package visibility

If you encounter `Error response from daemon: denied` when pulling the image:

- **Make the package public:** Repo → Packages → `dockerized-deployment` → Package settings → Change visibility → Public
- **Or grant access:** Package settings → Manage Actions access → add target repository with **Read** permission

## Using locally

### Build with a Kubeconfig

```bash
export KUBECONFIG_B64=$(cat ~/.kube/config | base64 -w0)
docker build --build-arg KUBECONFIG_B64="$KUBECONFIG_B64" -t dockerized-deployment .
```

### Run commands

```bash
# Query cluster
docker run --rm dockerized-deployment kubectl get nodes

# List Helm releases
docker run --rm dockerized-deployment helm list -A

# Multi-line script
docker run --rm dockerized-deployment sh -c '
  kubectl get ns
  helm list -A
'
```

### Override Kubeconfig at runtime

```bash
docker run --rm -e KUBECONFIG_B64="$OTHER_KUBECONFIG_B64" dockerized-deployment kubectl get nodes
```

### Test the published image

```bash
./scripts/test-container.sh
```

Optionally specify a custom image:

```bash
IMAGE=ghcr.io/my-org/dockerized-deployment:staging ./scripts/test-container.sh
```
