#!/usr/bin/env bash
# cleanup.sh — Remove previous Strimzi/KEDA installation to avoid CRD conflicts
# Run once manually before ArgoCD takes over the new structure.
# Does NOT remove ArgoCD.

set -euo pipefail

echo "==> [1/6] Removing ArgoCD Applications (pause GitOps reconciliation)..."
kubectl delete application -n argocd --all --ignore-not-found

echo "==> [2/6] Removing KafkaConnector CRs..."
kubectl delete kafkaconnector --all -n kafka --ignore-not-found

echo "==> [3/6] Removing KafkaConnect CRs..."
kubectl delete kafkaconnect --all -n kafka --ignore-not-found

echo "==> [4/6] Removing Kafka CR (triggers operator cleanup of pods/pvcs)..."
kubectl delete kafka --all -n kafka --ignore-not-found

echo "==> [5/6] Waiting for kafka namespace pods to terminate (max 120s)..."
kubectl wait --for=delete pod --all -n kafka --timeout=120s 2>/dev/null || true

echo "==> [6/6] Deleting namespaces kafka and keda..."
kubectl delete namespace kafka --ignore-not-found
kubectl delete namespace keda --ignore-not-found

echo ""
echo "Cleanup complete. Namespaces deleted:"
kubectl get namespaces | grep -E "kafka|keda" || echo "  (none — as expected)"
echo ""
echo "Next: git push + kubectl apply -f argocd-apps/"
