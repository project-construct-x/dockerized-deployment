# dockerized-deployment

Docker-Image mit **kubectl** und **Helm** für CI/CD. Führt beliebige Skripte (z. B. Helm-Deployments) aus.

## Image

- **kubectl** und **Helm** (Alpine-basiert)
- **Kubeconfig**: wird zur **Build-Zeit** in der Pipeline dieses Repos übergeben (Secret `KUBECONFIG_B64`) und als Default ins Image eingebacken. In einem Job kann man optional per Env **`KUBECONFIG_B64`** überschreiben; wenn nicht gesetzt, gilt immer die zur Build-Zeit eingebackene Kubeconfig.

## Build & Push

Bei Push auf `main` baut `.github/workflows/build-and-push.yml` pro Stage ein Image und pusht es nach **GHCR**. Die Stages sind als Matrix definiert (z. B. `staging`, `production`), jede mit einem eigenen Secret.

**In diesem Repository** müssen pro Stage Secrets gesetzt sein (base64-kodierte Kubeconfig):

| Stage | Secret | Image-Tag |
|---|---|---|
| `staging` | `KUBECONFIG_B64_STAGING` | `ghcr.io/<owner>/dockerized-deployment:staging` |
| `production` | `KUBECONFIG_B64_PRODUCTION` | `ghcr.io/<owner>/dockerized-deployment:production` |

Zum Anlegen eines Secrets von einer K3s-Instanz per SSH und `gh`:

```bash
SECRET_NAME=KUBECONFIG_B64_STAGING ./scripts/set-kubeconfig-secret.sh
```

Das Skript liest `/etc/rancher/k3s/k3s.yaml` vom SSH-Host, setzt die Server-URL auf `https://<host>:6443`, kodiert base64 und setzt das Secret per `gh secret set`. Optional: `SSH_HOST=myhost.example.com`, `SSH_USER=user`, `SECRET_NAME` oder `GITHUB_REPO=owner/repo` setzen.

- Push-Credentials: `GITHUB_TOKEN`

## Nutzung in einer anderen GitHub Action (z. B. Deployment)

Image als Container nutzen; **Default-Kubeconfig** ist die beim Build eingebackene (pro Stage). Optional: mit `KUBECONFIG_B64` im Job eine andere Kubeconfig setzen.

**Falls "Error response from daemon: denied" beim Pull:** Das andere Repo hat mit `GITHUB_TOKEN` standardmäßig kein Lese-Recht für dieses Package. Entweder:

- **Package öffentlich machen:** Repo dockerized-deployment → rechte Seite **Packages** → Package öffnen → **Package settings** → **Change visibility** → **Public**. Dann braucht der Deploy-Job keine speziellen Rechte.
- **Oder Zugriff erlauben:** Unter Package settings → Manage Actions access das Ziel-Repository mit **Read** hinzufügen.

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/projekt-construct-x/dockerized-deployment:staging
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    # Optional: eigene Kubeconfig statt der eingebackenen
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

Für Production einfach den Tag tauschen: `dockerized-deployment:production`.

Alternativ ohne `container:` – Image nur für einen Step:

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

Empfohlen: Job mit `container:` (erstes Beispiel), dann läuft der ganze Job im Image und `run: |` ist das multiline Skript.

## Lokal bauen & testen

Mit Kubeconfig zur Build-Zeit (Default im Image):

```bash
export KUBECONFIG_B64=$(cat ~/.kube/config | base64 -w0)
docker build --build-arg KUBECONFIG_B64="$KUBECONFIG_B64" -t dockerized-deployment .
docker run --rm dockerized-deployment kubectl get nodes
docker run --rm dockerized-deployment helm list -A
```

Optional: zur Laufzeit andere Kubeconfig setzen:

```bash
docker run --rm -e KUBECONFIG_B64="$OTHER_KUBECONFIG_B64" dockerized-deployment kubectl get nodes
```

Multiline-Skript (mit Default-Kubeconfig):

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

All non-code files are distributed under the Creative Commons Attribution 4.0 International license. See [LICENSE_non-code](./LICENSE_non-code) for more information.
