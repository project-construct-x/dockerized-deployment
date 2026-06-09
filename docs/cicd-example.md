# CI/CD Pipeline Example (Single Service)

Generic CI/CD workflow that builds a Docker image, pushes it to GHCR, and deploys via Helm using the `dockerized-deployment` container image.

## Workflow

```yaml
# .github/workflows/cicd.yaml
name: CI/CD Pipeline

on:
  push:
    paths-ignore:
      - "helm/**"
      - "README.md"
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  SERVICE_IMAGE: ghcr.io/${{ github.repository }}/my-service
  RELEASE_NAME: my-app
  NAMESPACE: production

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      service: ${{ steps.filter.outputs.service }}
      helm: ${{ steps.filter.outputs.helm }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Detect changed paths
        uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            service:
              - 'src/**'
              - 'Dockerfile'
            helm:
              - 'helm/**'

  build:
    needs: changes
    if: needs.changes.outputs.service == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.SERVICE_IMAGE }}
          tags: |
            type=sha,prefix=
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=my-service
          cache-to: type=gha,mode=max,scope=my-service

  deploy:
    needs: [changes, build]
    if: |
      always() &&
      (needs.changes.outputs.service == 'true' || needs.changes.outputs.helm == 'true') &&
      (needs.build.result == 'success' || needs.build.result == 'skipped') &&
      github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: read

    container:
      image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set image tag to commit SHA
        run: echo "IMAGE_TAG=$(echo "$GITHUB_SHA" | cut -c1-7)" >> "$GITHUB_ENV"

      - name: Create/update Kubernetes Secret
        env:
          APP_SECRET: ${{ secrets.APP_SECRET }}
        run: |
          set -euo pipefail
          if [[ -n "${APP_SECRET:-}" ]]; then
            kubectl -n "${NAMESPACE}" create secret generic my-app-secret \
              --from-literal=APP_SECRET="${APP_SECRET}" \
              --dry-run=client -o yaml | kubectl apply -f -
          fi

      - name: Deploy with Helm
        run: |
          set -euo pipefail
          kubectl cluster-info --request-timeout=15s

          helm upgrade --install "${RELEASE_NAME}" ./helm \
            --namespace "${NAMESPACE}" \
            --create-namespace \
            --set image.tag="${IMAGE_TAG}" \
            --wait \
            --timeout=5m
```

> Den Image-Tag auf `production` (oder eine andere Stage) ändern, um den jeweiligen Cluster anzusprechen.

## Key Patterns

### Path-based conditional builds

The `changes` job uses `dorny/paths-filter` to detect which parts of the codebase changed. Downstream jobs only run when relevant paths are modified:

```yaml
changes:
  outputs:
    service: ${{ steps.filter.outputs.service }}
  steps:
    - uses: dorny/paths-filter@v3
      with:
        filters: |
          service:
            - 'src/**'
            - 'Dockerfile'
```

### Container-based deploy job

The deploy job runs inside the `dockerized-deployment` image, giving it access to `kubectl` and `helm` without manual installation:

```yaml
container:
  image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
  credentials:
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

> Tag auf `production` ändern, um den Production-Cluster anzusprechen.

### Dynamic image tag

The short commit SHA is used as the image tag, ensuring each deployment references the correct build:

```yaml
- name: Set image tag to commit SHA
  run: echo "IMAGE_TAG=$(echo "$GITHUB_SHA" | cut -c1-7)" >> "$GITHUB_ENV"
```

### Idempotent secret management

Secrets are created or updated using `--dry-run=client -o yaml | kubectl apply -f -`, which works whether the secret exists or not:

```yaml
kubectl -n "${NAMESPACE}" create secret generic my-app-secret \
  --from-literal=APP_SECRET="${APP_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Helm deploy with safety flags

`--create-namespace` ensures the namespace exists, `--wait` blocks until the release is ready, and `--timeout` prevents hanging indefinitely:

```yaml
helm upgrade --install "${RELEASE_NAME}" ./helm \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set image.tag="${IMAGE_TAG}" \
  --wait \
  --timeout=5m
```
