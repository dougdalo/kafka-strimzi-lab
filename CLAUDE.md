# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository implements a **Kafka GitOps infrastructure** for a 3-node K3s cluster. It manages a Kafka cluster and Kafka Connect using the Strimzi Operator, with KEDA for event-driven autoscaling (HPA) of Kafka Connect workers based on consumer lag.

**Stack:** Kubernetes (K3s), Strimzi (0.45.0), ArgoCD, KEDA (2.12+), Kafka (KRaft), Kafka Connect.

## Repository Structure

```
/install        # Strimzi & KEDA Operator manifests (CRDs and Controllers)
/cluster        # Kafka Cluster (KRaft) Custom Resource definitions
/connect        # Kafka Connect, Connectors, and KEDA ScaledObjects
/argocd-apps    # ArgoCD Application manifests for all directories (App-of-Apps)
```

## Configuration Rules

- **Namespaces:** `kafka` (cluster/connect), `argocd` (ArgoCD), `keda` (KEDA operator)
- **Kafka Version:** 3.9.0 in KRaft mode (no ZooKeeper); requires `strimzi.io/kraft: enabled` annotation
- **High Availability (3-Node K3s):**
  - Use `podAntiAffinity` (preferred) for Kafka brokers and Connect workers
  - Replication factor: 3, Min In-Sync Replicas: 2
- **Storage:** Use `local-path` storage class (K3s default). PVCs at 10Gi. Set `deleteClaim: false`
- **Kafka Connect Builds:** Custom images (e.g., SFTP Sink) must be declared in `.spec.build` within the `KafkaConnect` CR
- **Connectivity:**
  - Internal: `[cluster-name]-kafka-bootstrap.kafka.svc:9092`
  - External: NodePort (32100) or Traefik Ingress for ArgoCD UI

## Strimzi 0.45.0 KRaft + Node Pools

- **KafkaNodePool CR required:** `strimzi.io/node-pools: enabled` annotation on the `Kafka` CR means `replicas`, `storage`, `resources`, `jvmOptions`, and `template` MUST be in a `KafkaNodePool` CR — those fields are ignored on the `Kafka` CR itself
- **KRaft combined roles:** `KafkaNodePool.spec.roles: [broker, controller]` — all 3 nodes act as both broker and controller
- **Storage class field:** Use `class: local-path` (not `storageClass`) in `PersistentClaimStorage` — the CRD schema uses `class`
- **StrimziPodSet:** Strimzi 0.45.0 uses `StrimziPodSet` (not `Deployment`) to manage Kafka and KafkaConnect pods — no `Deployment` object is created for Connect workers

## Autoscaling (KEDA + Strimzi)

- **Scaling Target:** Target the `KafkaConnect` CR directly via its `/scale` subresource — NOT a Deployment (Strimzi 0.45.0 uses StrimziPodSet, no Deployment exists)
  ```yaml
  scaleTargetRef:
    apiVersion: kafka.strimzi.io/v1beta2
    kind: KafkaConnect
    name: kafka-connect
  ```
- **ScaledObject Logic:**
  - Use the `kafka` trigger type
  - Define `bootstrapServers` and `consumerGroup` to monitor
  - Set `lagThreshold` (e.g., `"50"`) to trigger scaling
- **Resource Constraints:** `KafkaConnect` MUST have CPU/Memory requests defined for predictable HPA behavior

## ArgoCD GitOps Pattern

- **Sync Policy:** Automated sync with `prune: true`, `selfHeal: true`, and `ServerSideApply=true`
- **App-of-Apps:** The `/argocd-apps` folder contains the root definitions
- **Kustomize:** Preferred for `/install` and environment-specific overrides

## Useful Commands

### Cluster & GitOps

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd

# Check Strimzi & Kafka status
kubectl get kafka -n kafka
kubectl get kafkaconnect -n kafka
```

### KEDA & Scalability (Testing)

```bash
# Monitor KEDA ScaledObjects
kubectl get scaledobjects -n kafka

# Check HPA status (KEDA creates a standard HPA under the hood)
kubectl get hpa -n kafka

# Inspect KEDA operator logs for lag-check errors
kubectl logs -n keda -l app.kubernetes.io/name=keda-operator

# Trigger load test (example)
# kubectl run load-test --image=bitnami/kafka -- bash -c "kafka-producer-perf-test..."
```
