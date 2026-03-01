<p align="center">
  <img src="https://raw.githubusercontent.com/weak-fox/openclaw-helm/main/docs/assets/openclaw-logo.svg" alt="openclaw-helm logo" width="132" />
</p>

# OpenClaw Helm Chart

<p align="center">
  <a href="https://artifacthub.io/packages/helm/openclaw-helm-chart/openclaw"><img src="https://img.shields.io/badge/Artifact%20Hub-openclaw-417598" alt="Artifact Hub"></a>
  <a href="https://weak-fox.github.io/openclaw-helm"><img src="https://img.shields.io/badge/Helm%20Repo-weak--fox.github.io%2Fopenclaw--helm-0ea5e9" alt="Helm Repo"></a>
  <a href="https://github.com/weak-fox/openclaw-helm/releases"><img src="https://img.shields.io/badge/Chart-1.0.0-blue" alt="Chart Version"></a>
  <a href="https://github.com/openclaw/openclaw/releases"><img src="https://img.shields.io/badge/OpenClaw-2026.2.26-ef4444" alt="OpenClaw Version"></a>
  <a href="https://kubernetes.io/"><img src="https://img.shields.io/badge/Kubernetes-%3E%3D1.24-326ce5" alt="Kubernetes"></a>
  <a href="https://helm.sh/"><img src="https://img.shields.io/badge/Helm-v3.x-0f1689" alt="Helm"></a>
</p>

Project overview, demo GIF and architecture are in [weak-fox/openclaw-helm](https://github.com/weak-fox/openclaw-helm).

This chart deploys OpenClaw on Kubernetes using standard Helm templates.

## Architecture

![OpenClaw architecture](https://raw.githubusercontent.com/weak-fox/openclaw-helm/main/docs/assets/openclaw-architecture.svg)

| Component | Port | Notes |
| --- | --- | --- |
| OpenClaw Gateway | `18789` | In-pod listener |
| aio-sandbox | `8080` | In-pod listener (CDP/VNC/noVNC) |

## Key Point

- Model/provider config is easy to switch in values (`provider` / `api` / `baseUrl` / `model`).
- Control UI security behavior is easy to tune via `gateway.controlUi`.
- Uses `aio-sandbox` (agent-infra sandbox) plus shared workspace storage so browser actions are visible,
  OpenClaw workspace config files can be updated through browser-driven flows, and shell/Jupyter tasks can run in the same environment.
- Uses default OpenClaw gateway token flow (does not set `OPENCLAW_GATEWAY_PASSWORD`).
- API key is injected from Kubernetes Secret.
- Sandbox uses the agent-infra sidecar pattern (CDP + VNC + noVNC on port `8080`).
- `values.schema.json` is included for early validation (`helm lint` / install-time schema check).

## Values Layout

- `global`: naming and shared image registry
- `workload`: deployment and pod settings
- `gateway`: service, trusted proxies, control UI
- `openclaw`: image, API-key secret, config, bootstrap, runtime plugin config
- `sandbox`: browser sidecar settings
- `storage`: PVC, tmp, shared memory

## Image Repository Rule

All images use a consistent rule:
- If `repository` is absolute (for example `ghcr.io/openclaw/openclaw`), it is used directly.
- If `repository` is relative (for example `openclaw/openclaw`) and `global.imageRegistry` is set, final image is `<global.imageRegistry>/<repository>`.

## Path Variables

`init-config.sh` and `init-skills.sh` consume path values from Helm templates:

- `openclaw.paths.home`
- `openclaw.paths.homeDir`
- `openclaw.paths.workspaceDir`
- `openclaw.paths.sessionsDir`
- `sandbox.workspaceMountPath`
- `sandbox.shmMountPath`

This avoids hardcoding `/home/node/.openclaw` and makes path changes explicit in values.

## Image Pull Policies

Each image role can be controlled separately:

- `openclaw.image.pullPolicy` (main container)
- `openclaw.init.configPullPolicy` (init-config)
- `openclaw.init.skillsPullPolicy` (init-skills in online mode)
- `openclaw.bootstrap.seedImage.pullPolicy` (init-skills in offline mode)
- `sandbox.image.pullPolicy` (sandbox sidecar)

## Image Pull Secrets

Use existing registry secrets via `workload.imagePullSecrets` (default `[]`):

```yaml
workload:
  imagePullSecrets:
    - name: regcred
```

The chart only references these secrets and does not create them.

## Install

```bash
helm install openclaw ./charts/openclaw -n openclaw --create-namespace
```

## Basic Setup

1. Create namespace:

```bash
kubectl create namespace openclaw
```

2. Create API key secret:

```bash
kubectl create secret generic openclaw-api-key \
  -n openclaw \
  --from-literal=OPENCLAW_API_KEY=sk-xxxx
```

3. Install chart:

```bash
helm install openclaw ./charts/openclaw -n openclaw
```

## Control UI security note (important)

By default:

```yaml
gateway:
  controlUi:
    dangerouslyAllowHostHeaderOriginFallback: false
```

When your deployment is not strict loopback (common in Kubernetes), Control UI auth/origin checks may block startup unless you provide a secure production config.

For temporary/local validation only, you can use:

```yaml
gateway:
  controlUi:
    dangerouslyAllowHostHeaderOriginFallback: true
```

Quick bypass (local testing / debug):

```yaml
gateway:
  controlUi:
    allowInsecureAuth: true
    dangerouslyAllowHostHeaderOriginFallback: true
    dangerouslyDisableDeviceAuth: true
```

Or apply quickly via install/upgrade flags:

```bash
helm upgrade --install openclaw ./charts/openclaw -n openclaw \
  --set gateway.controlUi.allowInsecureAuth=true \
  --set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true \
  --set gateway.controlUi.dangerouslyDisableDeviceAuth=true
```

For production, follow official OpenClaw security guidance and run security checks:

- Control UI docs: https://docs.openclaw.ai/web/control-ui
- Security docs: https://docs.openclaw.ai/security
- Security audit command: `openclaw security audit --deep`

## Offline-seed install (your image set)

```bash
helm install openclaw ./charts/openclaw -n openclaw \
  -f ./charts/openclaw/examples/values.offline-seed.yaml
```

The example uses:
- `ghcr.io/agent-infra/sandbox:1.0.0.152`
- `ghcr.io/openclaw/openclaw:2026.2.26`
- `ghcr.io/weak-fox/openclaw-offline-seed:v1.0.0-oc-2026.2.26`

## Optional: chart-managed API key secret

```yaml
openclaw:
  secrets:
    apiKey:
      existingSecret: ""
      create: true
      name: openclaw-api-key
      key: OPENCLAW_API_KEY
      value: sk-xxxx
```

## Verify

```bash
helm lint ./charts/openclaw
helm template openclaw ./charts/openclaw >/tmp/openclaw-rendered.yaml
helm template openclaw ./charts/openclaw -f ./charts/openclaw/examples/values.offline-seed.yaml >/tmp/openclaw-rendered-offline.yaml
```
