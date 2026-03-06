# ArgoCD App of Apps Pattern

This directory contains ArgoCD Application manifests organized using the App of Apps pattern.

## Structure

```
argocd/
├── root-application.yaml    # Root Application that manages all child Applications
├── kustomization.yaml        # Kustomization file for easy management
├── infrastructure/           # Infrastructure Applications
│   ├── cert-manager.yaml
│   ├── longhorn.yaml
│   ├── metrics-server.yaml
│   ├── strimzi.yaml
│   ├── tailscale.yaml
│   ├── tailscale-config.yaml
│   ├── authentik.yaml
│   ├── sonarqube.yaml
│   └── prometheus-grafana.yaml
└── apps/                     # Application Applications
    ├── homepage.yaml
    ├── mongodb-running-race-tracker.yaml
    ├── redis-running-race-tracker.yaml
    ├── strimzi-running-race-tracker.yaml
    ├── kafka-topics-running-race-tracker.yaml
    ├── live-tracking-running-race-tracker.yaml
    ├── race-management-running-race-tracker.yaml
    ├── runner-registration-running-race-tracker.yaml
    └── simulation-running-race-tracker.yaml
```

## Sync Waves

Applications are organized using sync waves to handle dependencies:

- **Wave 1**: Base infrastructure (cert-manager, metrics-server, strimzi, tailscale, prometheus-grafana)
- **Wave 2**: Infrastructure that depends on wave 1 (longhorn, tailscale-config)
- **Wave 3**: Infrastructure that depends on wave 2 (authentik, sonarqube)
- **Wave 4**: Applications that depend on infrastructure (homepage)
- **Wave 5**: Data layer (mongodb, redis)
- **Wave 6**: Kafka setup (strimzi, kafka-topics)
- **Wave 7**: Application services (live-tracking, race-management, runner-registration, simulation)

## Deployment

### Initial Setup

1. Ensure ArgoCD is installed in your cluster
2. Bootstrap by applying the root application manually:

```bash
kubectl apply -f argocd/root-application.yaml
```

The root application will use Kustomize to process `kustomization.yaml`, which includes all child applications defined in the `infrastructure/` and `apps/` directories. ArgoCD will automatically discover and sync these child applications.

### Manual Sync

If you need to manually sync applications:

```bash
# Sync all applications
argocd app sync root-application

# Sync a specific application
argocd app sync infrastructure-cert-manager
```

### Monitoring

View application status:

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get root-application
```

## Differences from Flux

- **Dependencies**: ArgoCD uses sync waves instead of explicit `dependsOn` fields
- **Auto-sync**: Enabled by default with `syncPolicy.automated`
- **Namespace**: Applications are created in the `argocd` namespace
- **Sync Options**: Uses `CreateNamespace=true` and `PrunePropagationPolicy=foreground`

## Notes

- All applications use the same Git repository: `https://github.com/rburtelow/automation-homelab.git`
- SOPS decryption is supported if configured in ArgoCD
- Applications will automatically sync when changes are pushed to the `main` branch

