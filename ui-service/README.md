# ui-service

Generic chart for the OAN Next.js frontends. One chart, one set of overrides per UI.

```shell
helm install a2c-ui ./ui-service -f my-values.yaml \
  --set image.repository=<ecr>/oan/access-to-credit-system --set image.tag=staging-aws-12
```

Renders: Deployment, Service, ServiceAccount, plus optional ConfigMap (`env`), Secret (`secretEnv`),
HPA, Ingress and HTTPRoute (all off by default).

Note: values in `env` are read at container start. They only take effect for settings the app reads at
runtime; anything inlined at build time (e.g. A2C `API_BASE_URL`, `NEXT_PUBLIC_*`) is fixed in the image.

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| args | list | `[]` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `3` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPU | int | `75` |  |
| autoscaling.targetMemory | int | `75` |  |
| command | list | `[]` |  |
| containerName | string | `"ui"` |  |
| containerPort | int | `3000` |  |
| env | object | `{}` |  |
| envFrom | list | `[]` |  |
| existingSecret | string | `""` |  |
| extraEnv | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| httproute.annotations | object | `{}` |  |
| httproute.enabled | bool | `false` |  |
| httproute.hostnames[0] | string | `"ui.example.com"` |  |
| httproute.name | string | `""` |  |
| httproute.parentRefs[0].gatewayName | string | `"public-gateway"` |  |
| httproute.parentRefs[0].gatewayNamespace | string | `"networking"` |  |
| httproute.parentRefs[0].gatewaySectionName | string | `"http"` |  |
| httproute.rules[0].matches[0].path | string | `"/"` |  |
| httproute.rules[0].matches[0].pathType | string | `"PathPrefix"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `""` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"ui.cluster.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| initContainers | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| livenessProbe.initialDelaySeconds | int | `15` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.path | string | `"/"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| readinessProbe.initialDelaySeconds | int | `5` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| secretEnv | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.annotations | object | `{}` |  |
| service.port | int | `3000` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| sidecars | list | `[]` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |
