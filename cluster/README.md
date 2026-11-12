# Cluster bootstrap

`bootstrap-oan-dev.sh` creates the one deploy identity that Jenkins uses to install the Frappe services on the
oan_dev k3s node, and writes its kubeconfig. The identity is a ServiceAccount with:

| Namespace       | Access                                         | Used for                              |
| --------------- | ---------------------------------------------- | ------------------------------------- |
| each service    | built-in `admin` role                          | that service's Helm release           |
| `frappe-common` | get Secret `oan-frappe-common-db`, nothing else | copy the shared PostgreSQL password   |
| `api6-gateway`  | get/list Services                              | find the APISIX release's Redis       |

It cannot touch anything else. One token deploys every listed service; give a service its own ServiceAccount
(run the script with another `SA_NAME`) if that separation matters.

```bash
# On the node, or any machine with admin kubectl access:
API_SERVER=https://<address-the-agent-reaches>:6443 \
  bash cluster/bootstrap-oan-dev.sh /tmp/oan-dev.kubeconfig a2c grievance
```

Upload `/tmp/oan-dev.kubeconfig` as the Jenkins **Secret file** credential `oan-dev-kubeconfig`, then delete every
copy of it. Never commit it. Re-running adds namespaces and refreshes the kubeconfig. To see the manifests without
applying them: `bash cluster/bootstrap-oan-dev.sh --print-manifests a2c grievance`.

To keep an identity that exists already (the a2c deployer), pass its names:
`SA_NAMESPACE=a2c SA_NAME=jenkins-a2c-deployer bash cluster/bootstrap-oan-dev.sh <out> a2c grievance`.
