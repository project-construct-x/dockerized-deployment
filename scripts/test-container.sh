#!/usr/bin/env bash
# Simple test of the built image (GHCR): kubectl + helm with baked-in kubeconfig.
# Optional: GHCR_TOKEN (or GITHUB_TOKEN) + GHCR_USER for login with private image.
# Never store tokens in the repo; pass only via environment variable.

set -e

IMAGE="${IMAGE:-ghcr.io/projekt-construct-x/dockerized-deployment:staging}"

echo "Pull: $IMAGE"
PULL_OK=
if docker pull "$IMAGE" 2>/dev/null; then
  PULL_OK=1
fi
if [[ -z "$PULL_OK" ]]; then
  echo "Pull failed (image private?). Logging in to GHCR ..."
  TOKEN="${GHCR_TOKEN:-$GITHUB_TOKEN}"
  GH_USER="${GHCR_USER:-$(gh api user -q .login 2>/dev/null || true)}"
  if [[ -n "$TOKEN" && -n "$GH_USER" ]]; then
    echo "$TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin
  elif [[ -z "$TOKEN" && -n "$GH_USER" ]]; then
    gh auth token | docker login ghcr.io -u "$GH_USER" --password-stdin
  else
    [[ -z "$GH_USER" ]] && echo "GHCR_USER missing (e.g. export GHCR_USER=your-github-username)"
    [[ -z "$TOKEN" ]] && echo "Set token: export GHCR_TOKEN=ghp_... (or gh auth login)"
    exit 1
  fi
  if ! docker pull "$IMAGE"; then
    echo ""
    echo "Access denied. Either:"
    echo "  - Make the package public: Repo → Packages → dockerized-deployment → Package settings → Change visibility → Public"
    echo "  - Or grant your GitHub user read access to the package (Manage actions access)."
    exit 1
  fi
fi

echo ""
echo "--- kubectl get nodes ---"
docker run --rm "$IMAGE" kubectl get nodes

echo ""
echo "--- helm list -A ---"
docker run --rm "$IMAGE" helm list -A

echo ""
echo "Container test OK."
