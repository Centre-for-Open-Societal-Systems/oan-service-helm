# ui-service

Generic chart for the OAN Next.js frontends. One chart, one set of overrides per UI.

```
helm install a2c-ui ./ui-service -f my-values.yaml \
  --set image.repository=<ecr>/oan/access-to-credit-system --set image.tag=staging-aws-12
```

Renders: Deployment, Service, ServiceAccount, plus optional ConfigMap (`env`), Secret (`secretEnv`),
HPA, Ingress and HTTPRoute (all off by default).

Key values: `image.*`, `containerName`, `containerPort`/`service.port` (3000), `env`, `secretEnv`/`existingSecret`,
`extraEnv`, probes, `ingress`/`httproute`, `sidecars`.

Note: values in `env` are read at container start. They only take effect for settings the app reads at
runtime; anything inlined at build time (e.g. A2C `API_BASE_URL`, `NEXT_PUBLIC_*`) is fixed in the image.
