#!/usr/bin/env bash
# write-kubeconfig.sh - Write the kubeconfig of the Jenkins deploy identity on an OAN cluster
#
# The identity itself (ServiceAccount, token Secret, RoleBindings) is the oan-cluster-access chart in oan-helm
# (docs/cluster-access.md there); install it first. This script only reads the token Kubernetes wrote into the
# Secret `<SA_NAME>-token` and turns it into a kubeconfig, which stays out of Git.
#
# Run with kubectl access that can read that Secret (the node itself), then upload the file as the Jenkins
# "Secret file" credential `oan-dev-kubeconfig` and delete it. Never commit the output.
#
# Usage: write-kubeconfig.sh <output-kubeconfig>
# Environment (defaults in brackets):
#   API_SERVER    an address the Jenkins agent can reach [https://10.0.1.131:6443]
#   SA_NAMESPACE  namespace of the ServiceAccount, the chart's release namespace [a2c]
#   SA_NAME       name of the ServiceAccount, the chart's serviceAccount.name [jenkins-a2c-deployer]
set -euo pipefail

API_SERVER="${API_SERVER:-https://10.0.1.131:6443}"
SA_NAMESPACE="${SA_NAMESPACE:-a2c}"
SA_NAME="${SA_NAME:-jenkins-a2c-deployer}"
TOKEN_SECRET="${SA_NAME}-token"

OUT="${1:?usage: write-kubeconfig.sh <output-kubeconfig>}"

# The token controller fills the Secret a moment after the chart creates it.
TOKEN=""
for _ in $(seq 1 30); do
  TOKEN="$(kubectl -n "${SA_NAMESPACE}" get secret "${TOKEN_SECRET}" -o jsonpath='{.data.token}' | base64 -d)"
  [ -n "${TOKEN}" ] && break
  sleep 1
done
[ -n "${TOKEN}" ] || { echo "token of ${SA_NAMESPACE}/${TOKEN_SECRET} was not issued; is oan-cluster-access installed?" >&2; exit 1; }

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

echo "kubeconfig for ${SA_NAMESPACE}/${SA_NAME} written to ${OUT} (server ${API_SERVER})."
echo "Upload it as the Jenkins Secret file credential 'oan-dev-kubeconfig', then delete it."
