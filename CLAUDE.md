# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository implements a **Kafka GitOps infrastructure** for deploying and managing a Kafka cluster and Kafka Connect on Kubernetes using the Strimzi Operator, with GitOps methodology via ArgoCD.

**Stack:** Kubernetes (GKE/K3s), Strimzi Operator, ArgoCD, Kafka, Kafka Connect

## Repository Structure

```
/install      # Strimzi Operator manifests
/cluster      # Kafka Cluster Custom Resource definitions
/connect      # Kafka Connect and Connector definitions
/argocd-apps  # ArgoCD Application manifests pointing to the above directories
```

## Configuration Rules

- **Namespaces:** `kafka` for the cluster, `argocd` for the ArgoCD controller — keep these strictly separated
- **Kafka listeners:** configure both internal and external listeners
- **Storage:** decide between persistent (PVC-backed) or ephemeral storage per environment
- **Kafka Connect custom builds:** required when using connectors not bundled with Strimzi (e.g., SFTP Sink); these use a Dockerfile declared in the `KafkaConnect` CR's `.spec.build` section
- **Cluster:** 3-node K3s cluster
- **Storage:** Use `local-path` storage class for all PVCs
- **High Availability:** Implement `podAntiAffinity` (preferred) for Kafka brokers to distribute them across the 3 nodes
- **Storage Class:** Use `local-path` (K3s default).
- **Provisioning:** Storage is backed by Proxmox LVM-thin; keep PVC requests realistic (10Gi as defined).

## ArgoCD GitOps Pattern

Each subdirectory (`/install`, `/cluster`, `/connect`) should have a corresponding ArgoCD `Application` manifest in `/argocd-apps` that targets that path. This enables independent sync, health checks, and rollback per layer of the stack.
