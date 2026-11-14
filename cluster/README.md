# Cluster access

The Jenkins deploy identity that installs the Frappe services (its ServiceAccount, token Secret and
RoleBindings) is the `oan-cluster-access` chart in
[oan-helm](https://github.com/Centre-for-Open-Societal-Systems/oan-helm/blob/main/docs/cluster-access.md),
so every cluster gets the same access from Git. Install it there first.

`write-kubeconfig.sh` writes that identity's kubeconfig from the token Kubernetes issued. It creates and
changes nothing on the cluster.

```bash
# On the node, or any machine that can read the token Secret:
API_SERVER=https://<address-the-agent-reaches>:6443 \
  bash cluster/write-kubeconfig.sh /tmp/oan-dev.kubeconfig
```

Upload `/tmp/oan-dev.kubeconfig` as the Jenkins **Secret file** credential `oan-dev-kubeconfig`, then delete every
copy of it. Never commit it. `SA_NAMESPACE` and `SA_NAME` select another identity (defaults: `a2c`,
`jenkins-a2c-deployer`).
