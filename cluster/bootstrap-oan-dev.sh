#!/usr/bin/env bash
# bootstrap-oan-dev.sh - Create the shared Jenkins deploy identity on the oan_dev k3s node and write its kubeconfig
#
# One ServiceAccount deploys every Frappe service: it gets the built-in `admin` role in each namespace listed on
# the command line, read access to the one Secret `oan-frappe-common-db` in frappe-common (the create-site Job
# copies the shared PostgreSQL password from it) and get/list on Services in the APISIX namespace (the gateway
# deploy finds the release's Redis there). It can touch nothing else.
#
# Run on a machine with admin kubectl access to the cluster (the node itself), then upload the file as the Jenkins
# "Secret file" credential `oan-dev-kubeconfig` and delete it. Re-running is safe: it adds namespaces to the
# identity and refreshes the kubeconfig. Never commit the output.
#
# Usage: bootstrap-oan-dev.sh <output-kubeconfig> <namespace>...
#        bootstrap-oan-dev.sh --print-manifests <namespace>...
# Environment (defaults in brackets):
#   API_SERVER          an address the Jenkins agent can reach [https://10.0.1.131:6443]
#   SA_NAMESPACE        namespace of the ServiceAccount [oan-ci]
#   SA_NAME             name of the ServiceAccount [jenkins-oan-dev-deployer]
#   DB_SECRET_NAMESPACE namespace of the shared PostgreSQL Secret [frappe-common]
#   GATEWAY_NAMESPACE   namespace of the APISIX release, empty to skip its grant [api6-gateway]
# To keep an identity that exists already, pass its names, e.g. SA_NAMESPACE=a2c SA_NAME=jenkins-a2c-deployer.
set -euo pipefail

API_SERVER="${API_SERVER:-https://10.0.1.131:6443}"
SA_NAMESPACE="${SA_NAMESPACE:-oan-ci}"
SA_NAME="${SA_NAME:-jenkins-oan-dev-deployer}"
DB_SECRET_NAMESPACE="${DB_SECRET_NAMESPACE:-frappe-common}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE-api6-gateway}"
TOKEN_SECRET="${SA_NAME}-token"

manifests() {
  cat <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${SA_NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SA_NAME}
  namespace: ${SA_NAMESPACE}
---
# Token the Jenkins kubeconfig carries (Kubernetes no longer makes one for a ServiceAccount).
apiVersion: v1
kind: Secret
metadata:
  name: ${TOKEN_SECRET}
  namespace: ${SA_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
---
# Copy the shared PostgreSQL password into a service namespace. This one Secret only.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-read-db-secret
  namespace: ${DB_SECRET_NAMESPACE}
rules:
  - apiGroups: [""]
    resources: [secrets]
    resourceNames: [oan-frappe-common-db]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SA_NAME}-read-db-secret
  namespace: ${DB_SECRET_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins-read-db-secret
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: ${SA_NAMESPACE}
YAML
  if [ -n "${GATEWAY_NAMESPACE}" ]; then
    cat <<YAML
---
# Gateway deploy: find the APISIX release's Redis Service.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-read-services
  namespace: ${GATEWAY_NAMESPACE}
rules:
  - apiGroups: [""]
    resources: [services]
    verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SA_NAME}-read-services
  namespace: ${GATEWAY_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jenkins-read-services
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: ${SA_NAMESPACE}
YAML
  fi
  for ns in "$@"; do
    cat <<YAML
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ns}
---
# Full control inside this namespace only: its Helm release, Secrets and Jobs.
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${SA_NAME}
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: ${SA_NAMESPACE}
YAML
  done
}

if [ "${1:-}" = "--print-manifests" ]; then
  shift
  [ "$#" -ge 1 ] || { echo "usage: $0 --print-manifests <namespace>..." >&2; exit 1; }
  manifests "$@"
  exit 0
fi

OUT="${1:?usage: bootstrap-oan-dev.sh <output-kubeconfig> <namespace>...}"
shift
[ "$#" -ge 1 ] || { echo "at least one namespace is required" >&2; exit 1; }

manifests "$@" | kubectl apply -f -

# The token controller fills the Secret a moment after it is created.
TOKEN=""
for _ in $(seq 1 30); do
  TOKEN="$(kubectl -n "${SA_NAMESPACE}" get secret "${TOKEN_SECRET}" -o jsonpath='{.data.token}' | base64 -d)"
  [ -n "${TOKEN}" ] && break
  sleep 1
done
[ -n "${TOKEN}" ] || { echo "token of ${TOKEN_SECRET} was not issued" >&2; exit 1; }

CA="$(mktemp)"
trap 'rm -f "${CA}"' EXIT
kubectl -n "${SA_NAMESPACE}" get secret "${TOKEN_SECRET}" -o jsonpath='{.data.ca\.crt}' | base64 -d > "${CA}"

umask 077
rm -f "${OUT}"
kubectl config --kubeconfig="${OUT}" set-cluster oan-dev --server="${API_SERVER}" \
  --certificate-authority="${CA}" --embed-certs=true >/dev/null
kubectl config --kubeconfig="${OUT}" set-credentials jenkins --token="${TOKEN}" >/dev/null
kubectl config --kubeconfig="${OUT}" set-context oan-dev --cluster=oan-dev --user=jenkins >/dev/null
kubectl config --kubeconfig="${OUT}" use-context oan-dev >/dev/null

echo "kubeconfig written to ${OUT} (server ${API_SERVER}); namespaces: $*."
echo "Upload it as the Jenkins Secret file credential 'oan-dev-kubeconfig', then delete it."
