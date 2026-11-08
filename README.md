# Contents

### Frappe Helm Chart

Helm Chart to deploy a *frappe-bench*-like environment on Kubernetes. It adds following resources:

ConfigMaps:

- `nginx-config` is used to override default.conf for nginx reverse proxy and static assets container.

Deployments:

- `gunicorn` deployment contains frappe gunicorn.
- `nginx` deployment contains frappe static assets and nginx reverse proxy.
- `scheduler` deployment contains frappe scheduler.
- `socketio` deployment contains frappe socketio.
- `worker-d` deployment contains frappe default worker.
- `worker-l` deployment contains frappe long worker.
- `worker-s` deployment contains frappe short worker.

HorizontalPodAutoscalers:

- `gunicorn` hpa scales frappe gunicorn deployment.
- `nginx` hpa scales frappe nginx deployment.
- `socketio` hpa scales frappe socketio deployment.
- `worker-d` hpa scales frappe default worker deployment.
- `worker-l` hpa scales frappe long worker deployment.
- `worker-s` hpa scales frappe short worker deployment.

Ingresses:

- `ingress` with custom name can be dynamically generated using `helm template` and configured values.

HTTPRoutes:
- Gateway API's `httproute` with custom name can be dynamically generated using `helm template` and configured values.

Jobs:

- `vol-fix` job to fix volume permissions, changes the `uid` and `gid` to `1000:1000`.
- `bench-conf` job to configure db host, redis hosts and socketio port.
- `create-site` job to create new site.
- `create-multiple-sites` job to create multiple new sites.
- `drop-site` job to drop existing site.
- `drop-multiple-sites` job to create multiple new sites.
- `backup-push` job to backup and optionally push backup to S3 for existing site.
- `backup-multiple-sites` job to create multiple new sites.
- `migrate` job to migrate existing site.
- `migrate-multiple-sites` job to create multiple new sites.
- `clear-cache` job to clear cache after upgrade.
- `custom` job to run custom additional commands and configuration.

PVC:

- `frappe` persistent volume claim is used to allocate volume for sites and config deployed with this release
- `frappe-logs` persistent volume claim is used to allocate volume for logs

Secrets:

- `secret` is used to store `db-root-password` for external db host

Services:

- `gunicorn` service exposes pods from gunicorn deployment.
- `nginx` service exposes pods from nginx deployment.
- `socketio` service exposes pods from socketio deployment.

ServiceAccounts:

- `frappe` service account is used by all deployments.

### Release Wizard

This is a release script for maintainers. It does the following:

- Checks latest tag for given major release for frappe using git.
- Validates that release always bumps up.
- Bumps values.yaml and Chart.yaml for release changes
- Adds git tag for chart version
- Push to selected remote

This will trigger workflow to publish new version of helm chart.
