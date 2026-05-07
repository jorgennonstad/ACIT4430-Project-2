# Table of Contents

- [1 Prerequisites](#1-prerequisites)
- [2 Requirements](#2-requirements)
- [3 Project Overview](#3-project-overview)
  - [3.1 Folder Structure](#31-folder-structure)
- [4 SSH Access](#4-ssh-access)
- [5 How the Deployment Works](#5-how-the-deployment-works)
- [6 How to Run](#6-how-to-run)
  - [6.1 Terraform](#61-terraform)
  - [6.2 Ansible](#62-ansible)
- [7 How to Verify](#7-how-to-verify)
- [8 Accessing Dashboards](#8-accessing-dashboards)
- [9 Cleanup](#9-cleanup)
- [10 Architecture & Access](#10-architecture--access)

---

## 1 Prerequisites

You need access to the OsloMet network (EduVPN or campus WiFi).

Before deployment, make sure your public SSH key is available so you can connect to the master VM without a password prompt.

## 2 Requirements

The system is built as a small Kubernetes infrastructure with the following components:

- 1 master node (Kubernetes control plane)
- 3 worker nodes (Kubernetes workloads + Ceph storage)
- Ubuntu 24.04 LTS on all nodes
- OpenStack as the cloud provider
- Key-based SSH authentication
- Block storage attached to worker nodes for Ceph

All nodes are automatically provisioned and configured through Terraform and Ansible.

## 3 Project Overview

The project automates full infrastructure deployment from raw cloud resources to a running Kubernetes platform.

The deployment includes:

- Infrastructure provisioning with Terraform
- Node preparation with Ansible
- Kubernetes cluster deployment using Kubespray
- Distributed storage using Rook Ceph
- Monitoring stack (Prometheus + Grafana)
- Logging stack (Loki + Promtail)
- Backup system using Kasten K10

The system is fully automated and repeatable. Running the main playbook will rebuild the entire environment from scratch.

### 3.1 Folder Structure

```text
Oblig2/
└── ACIT4430-Project-2/
    ├── README.md
    ├── ansible/
    │   ├── main.yml
    │   ├── inventory/
    │   │   └── inventory
    │   └── plays/
    │       ├── 01_terraform.yml
    │       ├── 02_prepare_nodes.yml
    │       ├── 03_kubespray.yml
    │       ├── 04_ceph_rook.yml
    │       ├── 05_monitoring.yml
    │       ├── 06_logging.yml
    │       ├── 07_backup.yml
    │       └── 08_cleanup.yml
    ├── terraform/
    │   └── CreateVM.tf
    └── kubespray/
```

## 4 SSH Access

Master VM IP: `10.196.241.251`

Before you run the deployment, add your public SSH key to the master VM.

```bash
ssh-copy-id ubuntu@10.196.241.251
```

You can test the connection directly with:

```bash
ssh ubuntu@10.196.241.251
```

## 5 How the Deployment Works

The deployment is split into a few stages:

- Terraform creates the OpenStack infrastructure and inventory.
- Ansible prepares the nodes and installs Kubernetes.
- Kubespray brings up the cluster.
- Rook Ceph provides storage.
- Monitoring, logging, and backup are installed on top.

The main Ansible playbook is the entry point for the full setup. It runs the stage playbooks in order so the cluster is built from scratch in a repeatable way.

## 6 How to Run

The deployment is normally run from Ansible and will call Terraform as needed; you do not need to run Terraform manually unless debugging infrastructure.

All verification commands below should be run from the master node and prefixed with `sudo` (for example `sudo kubectl get nodes`).

### 6.1 Terraform (infrastructure)

Terraform provisions the OpenStack infrastructure used by the project:

- Master node
- Worker nodes
- Block storage volumes
- Network configuration
- Dynamic Ansible inventory

If you need to run Terraform manually (not required for a normal run):

```bash
cd Oblig2/ACIT4430-Project-2/terraform
terraform init
terraform apply
```

### 6.2 Ansible (full deployment)

Run the full deployment from the Ansible folder using the provided inventory. This will perform node prep, Kubespray (Kubernetes), Rook-Ceph, monitoring, logging and Kasten K10 steps.

```bash
cd Oblig2/ACIT4430-Project-2/ansible
ansible-playbook -i inventory/inventory main.yml
```

The Ansible run is the normal way to deploy everything — Terraform is invoked by the playbooks when needed, so manual Terraform is optional.

## 7 How to Verify

SSH to the master node and run the following checks with `sudo`.

### 7.1 Cluster nodes

Verify all nodes are present and `Ready`:

```bash
sudo kubectl get nodes
```

Expected: one master and three workers in `Ready` state.

### 7.2 All pods

Check there are no CrashLoopBackOff / Pending / Error pods:

```bash
sudo kubectl get pods -A
```

### 7.3 Storage (Rook-Ceph)

```bash
sudo kubectl get pods -n rook-ceph
sudo kubectl -n rook-ceph get cephcluster
```

`CephCluster` should show `HEALTH_OK` and pods should be `Running` / `Completed`.

### 7.4 Monitoring

```bash
sudo kubectl get pods -n monitoring
sudo kubectl get pvc -n monitoring
```

Pods should be `Running` and PVCs `Bound`.

### 7.5 Logging

```bash
sudo kubectl get pods -n logging
sudo kubectl get pvc -n logging
```

Pods should be `Running` and PVCs `Bound`.

### 7.6 Backup (Kasten K10)

```bash
sudo kubectl get pods -n kasten-io
sudo kubectl get pvc -n kasten-io
sudo kubectl get applications.apps.kio.kasten.io -A
sudo kubectl get policies.config.kio.kasten.io -n kasten-io
```

Pods should be `Running`. `applications.apps.kio.kasten.io` should list protected namespaces (for example `default`, `monitoring`, `logging`) and policies should report status.

You can also inspect namespaces and workloads:

```bash
sudo kubectl get ns
sudo kubectl get pods -A
```

## 8 Accessing Dashboards

Both dashboards are exposed and can be acessed as long as you are connected to the OsloMet nettwork

### 8.1 Grafana (Monitoring)

Open in your browser:

```
http://{master-node-ip}:30080
```

Login with username & password `admin`.

**What to look for:**
- Dashboards panel on the left; browse to "Kubernetes / Compute Resources" or similar to see cluster metrics.
- Check that nodes, pods, CPU, and memory usage are being recorded.
- Prometheus should be listed under "Data Sources".

**Optional: Access Prometheus directly from Grafana**

Inside Grafana, go to **Explore** → select **Prometheus** data source. You can run queries like:

```
node_memory_MemAvailable_bytes
kubernetes_build_info
```

### 8.2 Kasten K10 (Backup)

Open in your browser:

```
http://{master-node-ip}:30808/k10/#
```

**What to look for:**
- **Applications:** You should see `default`, `monitoring`, `logging` and `rook-ceph` listed.
- **Policies:** Check that backup policies exist for each namespace (daily backups, 7-day retention).
- **Dashboard:** Verify that the policy status shows active/enabled and ready to back up applications.

## 9 Cleanup

When you want to remove the stack, run the cleanup playbook from the Ansible directory:

```bash
cd Oblig2/ACIT4430-Project-2/ansible
ansible-playbook -i inventory/inventory plays/08_cleanup.yml
```

## 10 Architecture & Access

**Dashboards:**
- **Grafana:** http://{master-node-ip}:30080/ — Monitoring, metrics, Prometheus queries, Loki logs.
- **Kasten K10:** http://{master-node-ip}:30808/k10/# — Backup applications, policies, snapshots.

**Kubernetes API:** master node via `kubectl` with `/etc/kubernetes/admin.conf`.

**Storage:** Rook Ceph distributed across worker nodes (block storage for PVCs and snapshots).
