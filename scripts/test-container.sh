#!/usr/bin/env bash
# Einfacher Test des gebauten Images (GHCR): kubectl + helm mit eingebackener Kubeconfig.
# Optional: GHCR_TOKEN (oder GITHUB_TOKEN) + GHCR_USER für Login bei privatem Image.
# Token nie im Repo speichern; nur per Umgebungsvariable übergeben.

set -e

IMAGE="${IMAGE:-ghcr.io/projekt-construct-x/dockerized-deployment:staging}"

echo "Pull: $IMAGE"
PULL_OK=
if docker pull "$IMAGE" 2>/dev/null; then
  PULL_OK=1
fi
if [[ -z "$PULL_OK" ]]; then
  echo "Pull fehlgeschlagen (Image privat?). Melde bei GHCR an ..."
  TOKEN="${GHCR_TOKEN:-$GITHUB_TOKEN}"
  GH_USER="${GHCR_USER:-$(gh api user -q .login 2>/dev/null || true)}"
  if [[ -n "$TOKEN" && -n "$GH_USER" ]]; then
    echo "$TOKEN" | docker login ghcr.io -u "$GH_USER" --password-stdin
  elif [[ -z "$TOKEN" && -n "$GH_USER" ]]; then
    gh auth token | docker login ghcr.io -u "$GH_USER" --password-stdin
  else
    [[ -z "$GH_USER" ]] && echo "GHCR_USER fehlt (z. B. export GHCR_USER=dein-github-username)"
    [[ -z "$TOKEN" ]] && echo "Token setzen: export GHCR_TOKEN=ghp_... (oder gh auth login)"
    exit 1
  fi
  if ! docker pull "$IMAGE"; then
    echo ""
    echo "Zugriff verweigert. Entweder:"
    echo "  - Package auf Public stellen: Repo → Packages → dockerized-deployment → Package settings → Change visibility → Public"
    echo "  - Oder deinem GitHub-User Leserecht für das Package geben (Manage actions access)."
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
echo "Container-Test OK."
