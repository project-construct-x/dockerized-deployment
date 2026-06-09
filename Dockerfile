# dockerized-deployment: kubectl + helm, base64 kubeconfig, für GHA-Deployments
FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates

# kubectl (stable version)
ENV KUBECTL_VERSION=1.31.3
RUN curl -sSLo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# Helm
ENV HELM_VERSION=3.16.4
RUN curl -sSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm \
    && chmod +x /usr/local/bin/helm

# Kubeconfig zur Build-Zeit (Pipeline übergibt KUBECONFIG_B64); optional überschreibbar per Env zur Laufzeit
ARG KUBECONFIG_B64
RUN if [ -n "$KUBECONFIG_B64" ]; then \
      mkdir -p /opt/kubeconfig && \
      echo "$KUBECONFIG_B64" | base64 -d > /opt/kubeconfig/default && \
      chmod 600 /opt/kubeconfig/default; \
    fi
# ENV sorgt dafür, dass kubectl auch bei überschriebenem Entrypoint (z. B. GHA container: jobs) die Kubeconfig nutzt
ENV KUBECONFIG=/opt/kubeconfig/default

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sh"]
