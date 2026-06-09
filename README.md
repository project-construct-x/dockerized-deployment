# dockerized-deployment

Docker image with **kubectl** and **Helm** for CI/CD. Runs arbitrary scripts (e.g. Helm deployments).

## Image

- **kubectl** and **Helm** (Alpine-based)
- **Kubeconfig**: passed at **build time** via the pipeline of this repo (secret `KUBECONFIG_B64`) and baked into the image as default. In a job, you can optionally override it via env **`KUBECONFIG_B64`**; if not set, the kubeconfig baked in at build time is always used.

> **Why not GitHub organization secrets?** GitHub offers [organization-level secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-an-organization) that can be shared across all repositories in an org — but this is a **paid feature** (GitHub Enterprise). This repo achieves the same result with a free approach: one central place for cluster credentials, distributed as a pre-baked container image.

## Build & Push

On push to `main`, `.github/workflows/build-and-push.yml` builds an image per stage and pushes it to **GHCR**. Stages are defined as a matrix (e.g. `staging`, `production`), each with its own secret.

**In this repository**, secrets must be set per stage (base64-encoded kubeconfig):

| Stage | Secret | Image Tag |
|---|---|---|
| `staging` | `KUBECONFIG_B64_STAGING` | `ghcr.io/<owner>/dockerized-deployment:staging` |
| `production` | `KUBECONFIG_B64_PRODUCTION` | `ghcr.io/<owner>/dockerized-deployment:production` |

To create a secret from a K3s instance via SSH and `gh`:

```bash
SECRET_NAME=KUBECONFIG_B64_STAGING ./scripts/set-kubeconfig-secret.sh
```

The script reads `/etc/rancher/k3s/k3s.yaml` from the SSH host, sets the server URL to `https://<host>:6443`, base64-encodes it, and sets the secret via `gh secret set`. Optional: set `SSH_HOST=myhost.example.com`, `SSH_USER=user`, `SECRET_NAME`, or `GITHUB_REPO=owner/repo`.

- Push credentials: `GITHUB_TOKEN`

## Usage in another GitHub Action (e.g. Deployment)

Use the image as a container; the **default kubeconfig** is the one baked in at build time (per stage). Optionally, set `KUBECONFIG_B64` in the job to use a different kubeconfig.

**If you get "Error response from daemon: denied" on pull:** The other repo does not have read access to this package by default with `GITHUB_TOKEN`. Either:

- **Make the package public:** Repo dockerized-deployment → right sidebar **Packages** → open package → **Package settings** → **Change visibility** → **Public**. Then the deploy job does not need special permissions.
- **Or grant access:** Under [Package settings → Manage Actions access](https://github.com/orgs/project-construct-x/packages/container/dockerized-deployment/settings), add the target repository with **Read** permission.

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    # Optional: own kubeconfig instead of the baked-in one
    # env:
    #   KUBECONFIG_B64: ${{ secrets.KUBECONFIG_B64 }}
    steps:
      - name: Helm deploy
        run: |
          helm repo add myrepo https://charts.example.com
          helm upgrade --install myapp myrepo/myapp \
            --namespace staging \
            --set image.tag="${{ github.sha }}"
```

For production, simply swap the tag: `dockerized-deployment:production`.

Alternatively, without `container:` – image only for a single step:

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

Recommended: job with `container:` (first example), then the entire job runs inside the image and `run: |` is the multiline script.

## Local Build & Test

With kubeconfig at build time (default in image):

```bash
export KUBECONFIG_B64=$(cat ~/.kube/config | base64 -w0)
docker build --build-arg KUBECONFIG_B64="$KUBECONFIG_B64" -t dockerized-deployment .
docker run --rm dockerized-deployment kubectl get nodes
docker run --rm dockerized-deployment helm list -A
```

Optional: set a different kubeconfig at runtime:

```bash
docker run --rm -e KUBECONFIG_B64="$OTHER_KUBECONFIG_B64" dockerized-deployment kubectl get nodes
```

Multiline script (with default kubeconfig):

```bash
docker run --rm dockerized-deployment sh -c '
  kubectl get ns
  helm list -A
'
```

## Documentation

This documentation is located in the `/docs` folder.

## License

All code files are distributed under the Apache 2.0 license. See [LICENSE](./LICENSE) for more information.

All non-code files are distributed under the Creative Commons Attribution 4.0 International license. See [LICENSE_non_code](./LICENSE_non_code) for more information.
