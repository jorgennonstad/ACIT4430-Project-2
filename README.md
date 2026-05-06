# Table of Contents

- [1 Prerequisites](#1-prerequisites)
- [2 Requirements](#2-requirements)
- [3 Project Overview](#3-project-overview)
- [4 How to run the deployment](#4-how-to-run-the-deployment)
  - [4.1 main.yml](#41-mainyml)
  - [4.2 Terraform](#42-terraform)
  - [4.3 Node Preparation](#43-node-preparation)
  - [4.4 Kubernetes Deployment](#44-kubernetes-deployment)
  - [4.5 Ceph Storage](#45-ceph-storage)
  - [4.6 Monitoring](#46-monitoring)
  - [4.7 Logging](#47-logging)
  - [4.8 Backup (Kasten K10)](#48-backup-kasten-k10)
- [5 How to verify](#5-how-to-verify)
- [6 Folder Structure](#6-folder-structure)

---

## 1 Prerequisites

You need access to the OsloMet network (EduVPN or campus WiFi).

To access the master node, you must add your public SSH key to the server before deployment. After this, you can SSH into the master node using:

```bash
ssh ubuntu@<MASTER_IP>

Do not share your private SSH key.

2 Requirements

The system is built as a small Kubernetes infrastructure with the following components:

1 master node (Kubernetes control plane)
3 worker nodes (Kubernetes workloads + Ceph storage)
Ubuntu 24.04 LTS on all nodes
OpenStack as the cloud provider
Key-based SSH authentication
Block storage attached to worker nodes for Ceph

All nodes are automatically provisioned and configured through Terraform and Ansible.

3 Project Overview

The project automates full infrastructure deployment from raw cloud resources to a running Kubernetes platform.

The deployment includes:

Infrastructure provisioning with Terraform
Node preparation with Ansible
Kubernetes cluster deployment using Kubespray
Distributed storage using Rook Ceph
Monitoring stack (Prometheus + Grafana)
Logging stack (Loki + Promtail)
Backup system using Kasten K10

The system is fully automated and repeatable. Running the main playbook will rebuild the entire environment from scratch.

4 How to run the deployment

All deployment steps are controlled through the main Ansible playbook:

ansible-playbook main.yml

This executes all stages in order.

4.1 main.yml

The main playbook runs the full deployment pipeline:

Terraform provisioning
Node preparation
Kubernetes cluster deployment
Ceph storage setup
Monitoring installation
Logging installation
Backup system installation

Each stage is separated into its own playbook for clarity and maintainability.

4.2 Terraform

Terraform is used to create all infrastructure in OpenStack.

It provisions:

Master node
Worker nodes
Block storage volumes
Network configuration
Dynamic Ansible inventory

Run manually if needed:

cd terraform
terraform init
terraform apply
4.3 Node Preparation

This step prepares all nodes for Kubernetes.

It:

Waits for SSH availability
Disables swap
Loads required kernel modules
Installs base packages
Configures Kubernetes networking
Wipes old Ceph disk data on worker nodes

This ensures all nodes are in a consistent state before cluster deployment.

4.4 Kubernetes Deployment

Kubernetes is installed using Kubespray.

It:

Generates cluster inventory
Installs Kubernetes components on all nodes
Configures control plane and workers
Initializes cluster networking

Result:

1 control plane node
3 worker nodes
4.5 Ceph Storage

Rook Ceph is deployed inside Kubernetes.

It:

Uses worker node disks
Creates a distributed storage cluster
Enables replication and fault tolerance
Provides dynamic storage provisioning via StorageClass
4.6 Monitoring

The monitoring stack includes:

Prometheus (metrics collection)
Grafana (visualization)

It is installed using Helm and stores data in Ceph-backed storage.

4.7 Logging

The logging stack includes:

Loki (log storage)
Promtail (log collection)

Logs from all containers are centralized and accessible through Grafana.

4.8 Backup (Kasten K10)

Kasten K10 is used for Kubernetes backups.

It:

Creates snapshot-based backups using Ceph
Uses backup policies per namespace
Supports scheduled and on-demand backups
Provides recovery capabilities for workloads and data
5 How to verify

After deployment, you can verify the system using:

kubectl get nodes
kubectl get pods -A

Check specific components:

kubectl get pods -n rook-ceph
kubectl get pods -n monitoring
kubectl get pods -n logging
kubectl get pods -n kasten-io

To verify Ceph:

kubectl -n rook-ceph get cephcluster

To verify Kasten:

kubectl get policies.config.kio.kasten.io -n kasten-io
6 Folder Structure
[INSERT PROJECT FOLDER TREE HERE]
Access Notes

To access services:

Kubernetes API: master node
Grafana: via port-forward
Kasten dashboard: via port-forward
Loki: integrated in Grafana

Example:

kubectl -n monitoring port-forward svc/grafana 3000:80
kubectl -n kasten-io port-forward svc/gateway 8080:80