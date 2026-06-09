#!/bin/sh
set -e

KUBE_DIR="${HOME:-/root}/.kube"
mkdir -p "$KUBE_DIR"

if [ -n "${KUBECONFIG_B64}" ]; then
  # Runtime override: job can set its own kubeconfig via env
  echo "$KUBECONFIG_B64" | base64 -d > "$KUBE_DIR/config"
  chmod 600 "$KUBE_DIR/config"
  export KUBECONFIG="$KUBE_DIR/config"
elif [ -f /opt/kubeconfig/default ]; then
  # Default: kubeconfig baked in at build time
  export KUBECONFIG=/opt/kubeconfig/default
fi

if [ $# -eq 0 ]; then
  exec /bin/sh
fi
exec "$@"
