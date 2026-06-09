# Configuration Reference

## Environment Variables

| Variable | Scope | Description |
|---|---|---|
| `KUBECONFIG_B64` | Build-time (`--build-arg`) | Base64-encoded Kubeconfig baked into the image as default |
| `KUBECONFIG_B64` | Runtime (`env`) | Override the baked-in Kubeconfig; decoded to `~/.kube/config` at container start |
| `KUBECONFIG` | Runtime (internal) | Set by `entrypoint.sh` to point to the active Kubeconfig file |

## GitHub Actions Secrets

Each stage needs its own secret (see [Stage Matrix](#stage-matrix)).

| Secret | Required | Description |
|---|---|---|
| `KUBECONFIG_B64_<STAGE>` | Per stage | Base64-encoded kubeconfig for the respective stage, baked into the image as build-arg |
| `GITHUB_TOKEN` | Automatic | Provided by GitHub; used to authenticate to GHCR |

## Stage Matrix

Stages are defined in `.github/workflows/build-and-push.yml` as a matrix. Each entry is a tuple of `name` (stage identifier, used as image tag) and `secret` (name of the GitHub secret containing the kubeconfig).

```yaml
strategy:
  fail-fast: false
  matrix:
    stage:
      - name: staging
        secret: KUBECONFIG_B64_STAGING
      - name: production
        secret: KUBECONFIG_B64_PRODUCTION
```

The matrix ensures the same build job runs once per stage — with the respective secret and stage-specific image tags:

| Stage | Secret | Image Tag (latest) | Image Tag (SHA) |
|---|---|---|---|
| `staging` | `KUBECONFIG_B64_STAGING` | `staging` | `staging-abc1234` |
| `production` | `KUBECONFIG_B64_PRODUCTION` | `production` | `production-abc1234` |

New stages are simply added as another tuple in the matrix:

```yaml
- name: development
  secret: KUBECONFIG_B64_DEVELOPMENT
```

## Scripts

### `scripts/set-kubeconfig-secret.sh`

Reads `/etc/rancher/k3s/k3s.yaml` from a K3s host via SSH, updates the server URL, base64-encodes it, and stores it as a GitHub secret.

| Env Variable | Default | Description |
|---|---|---|
| `SSH_HOST` | `your-k3s-host.example.com` | K3s host to SSH into |
| `SSH_USER` | `root` | SSH username |
| `GITHUB_REPO` | (current repo) | Target GitHub repository |
| `KUBECONFIG_B64_FILE` | `$REPO_ROOT/.kubeconfig.b64` | Local output path |
| `SUDO_PW` | (prompted) | Sudo password for the K3s host |

### `scripts/test-container.sh`

Pulls and runs the published image, verifying `kubectl get nodes` and `helm list -A`.

| Env Variable | Default | Description |
|---|---|---|
| `IMAGE` | `ghcr.io/projekt-construct-x/dockerized-deployment:staging` | Image to test |
| `GHCR_TOKEN` | (optional) | Token for GHCR login |
| `GHCR_USER` | (optional) | GitHub username for GHCR login |

## Image Versions

Baked into the Dockerfile:

| Tool | Version |
|---|---|
| Alpine | 3.21 |
| kubectl | 1.31.3 |
| Helm | 3.16.4 |

## Kubeconfig Resolution

`entrypoint.sh` resolves the active Kubeconfig in this order:

1. If `KUBECONFIG_B64` is set at runtime → decode to `~/.kube/config`, use it
2. If `/opt/kubeconfig/default` exists (baked at build time) → use it
3. Otherwise → kubectl/Helm will use default paths or fail
