# Frappe Common

Database chart for Frappe. It deploys **only** the database used by the `frappe-service` chart: MariaDB or PostgreSQL. Frappe itself (gunicorn, workers, nginx, socketio, site jobs) and Redis/Valkey/Dragonfly are deployed by `frappe-service`.

## Database options

Enable exactly one of:

| Option | Values key | Service (port) |
|--------|------------|----------------|
| MariaDB StatefulSet | `mariadb-sts.enabled: true` + `mariadb-sts.rootPassword` | `<fullname>-mariadb-sts` (3306) |
| PostgreSQL StatefulSet (default) | `postgresql-sts.enabled: true` + `postgresql-sts.postgresPassword` | `<fullname>-postgresql-sts` (5432) |
| Bitnami MariaDB subchart (legacy) | `mariadb-subchart.enabled: true` | `<release>-mariadb-subchart` (3306) |
| Bitnami PostgreSQL subchart (legacy) | `postgresql-subchart.enabled: true` | `<release>-postgresql-subchart` (5432) |

The StatefulSet passwords are stored in the `<fullname>` Secret under `mariadb-root-password` / `postgres-password`. Bitnami subchart values are passed through under `mariadb-subchart:` / `postgresql-subchart:`. `<fullname>` is the release name when it contains `frappe-common`, otherwise `<release>-frappe-common`. The release notes print the endpoint to use.

## Installation

```shell
helm upgrade --install frappe-common ./frappe-common -n frappe \
  --set postgresql-sts.postgresPassword=<password>
```

Then point `frappe-service` at it as an external database (disable its own `mariadb-sts`/`postgresql-sts`):

```yaml
postgresql-sts:
  enabled: false
dbHost: frappe-common-postgresql-sts.frappe.svc
dbPort: "5432"
dbRootUser: postgres
dbExistingSecret: frappe-common
dbExistingSecretPasswordKey: postgres-password
```

For moving from the Bitnami subcharts to the StatefulSets, see [MIGRATION.md](MIGRATION.md).

## Databases for other applications

Applications that are not Frappe sites (Frappe's create-site job makes its own database) can share the PostgreSQL
through `appDatabases`. A post-install/post-upgrade Job creates each database and a login role that owns it. The role
has `LOGIN` only (no superuser, createdb or createrole), and `CONNECT` is revoked from `PUBLIC`, so the other apps on
the server cannot open the database. An existing database is never dropped or re-owned, and an existing role gets its
password from the Secret again on every upgrade.

```yaml
appDatabases:
  - name: leads_db
    user: leads_api
  - name: lead_db
    user: leads_telephony
```

For each entry the chart creates Secret `<fullname>-app-<name>` (`_` becomes `-`, e.g.
`frappe-common-app-leads-db`) with the keys `host`, `port`, `database`, `username`, `password` and `jdbc-url`. The
password is random, reused on upgrade and kept on uninstall. Copy the Secret into the application's namespace, or put
its values in the application's own secret values. To supply the login instead, set `existingSecret` (with `userKey`
and `passwordKey`, default `username` / `password`) to a Secret in this release's namespace.

## Parameters

![Version: 8.0.91-oan.3](https://img.shields.io/badge/Version-8.0.91--oan.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v16.54.0](https://img.shields.io/badge/AppVersion-v16.54.0-informational?style=flat-square)

MariaDB and PostgreSQL databases for Frappe

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | mariadb-subchart(mariadb) | 11.5.7 |
| https://charts.bitnami.com/bitnami | postgresql-subchart(postgresql) | 12.1.6 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| appDatabases | list | `[]` | Databases for applications that are not Frappe sites (Frappe's create-site job makes its own), on the PostgreSQL of this release. A post-install/post-upgrade Job creates each database and a login role that owns it (LOGIN only, CONNECT revoked from PUBLIC). Existing databases are never dropped or re-owned. Without existingSecret the chart creates Secret <fullname>-app-<name, _ as -> (keys host, port, database, username, password, jdbc-url) with a random password, reuses it on upgrade and keeps it on uninstall. |
| appDatabasesJob.activeDeadlineSeconds | int | `900` | How long the Job waits for PostgreSQL and the Secrets before it fails. |
| appDatabasesJob.image | string | `""` | psql image (15 or later). Empty: the image of the enabled PostgreSQL. |
| appDatabasesJob.resources.limits.memory | string | `"128Mi"` |  |
| appDatabasesJob.resources.requests.cpu | string | `"25m"` |  |
| appDatabasesJob.resources.requests.memory | string | `"32Mi"` |  |
| fullnameOverride | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| mariadb-sts.enabled | bool | `false` |  |
| mariadb-sts.image.pullPolicy | string | `"IfNotPresent"` |  |
| mariadb-sts.image.repository | string | `"mariadb"` |  |
| mariadb-sts.image.tag | string | `"10.6"` |  |
| mariadb-sts.myCnf | string | `"[mysqld]\nskip-character-set-client-handshake\nskip-innodb-read-only-compressed\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\nmax_connections=300\n"` |  |
| mariadb-sts.persistence.size | string | `"8Gi"` |  |
| mariadb-sts.resources.requests.cpu | string | `"250m"` |  |
| mariadb-sts.resources.requests.memory | string | `"512Mi"` |  |
| mariadb-sts.rootPassword | string | `""` |  |
| mariadb-subchart.enabled | bool | `false` |  |
| mariadb-subchart.image.repository | string | `"bitnamilegacy/mariadb"` |  |
| mariadb-subchart.image.tag | string | `"10.6.17-debian-11-r10"` |  |
| nameOverride | string | `""` |  |
| podSecurityContext.supplementalGroups[0] | int | `1000` |  |
| postgresql-sts.enabled | bool | `false` |  |
| postgresql-sts.extraArgs | list | `[]` |  |
| postgresql-sts.image.pullPolicy | string | `"IfNotPresent"` |  |
| postgresql-sts.image.repository | string | `"postgres"` |  |
| postgresql-sts.image.tag | string | `"15"` |  |
| postgresql-sts.maxConnections | int | `300` |  |
| postgresql-sts.persistence.size | string | `"8Gi"` |  |
| postgresql-sts.postgresPassword | string | `""` |  |
| postgresql-sts.postgresUser | string | `"postgres"` |  |
| postgresql-sts.resources.requests.cpu | string | `"250m"` |  |
| postgresql-sts.resources.requests.memory | string | `"512Mi"` |  |
| postgresql-subchart.enabled | bool | `true` |  |
| postgresql-subchart.image.repository | string | `"bitnamilegacy/postgresql"` |  |
| postgresql-subchart.image.tag | string | `"16.4.0-debian-12-r14"` |  |
