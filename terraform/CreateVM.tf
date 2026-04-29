terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
}

# ---------------- MASTER ----------------
resource "openstack_compute_instance_v2" "master" {
  count       = 1
  name        = "master"
  image_name  = "Ubuntu-24.04-LTS (Noble Numbat)"
  flavor_name = "aem.2c4r.50g"

  network { name = "oslomet" }

  key_pair        = "MasterVMKey"
  security_groups = ["default"]
}

# ---------------- WORKERS ----------------
resource "openstack_compute_instance_v2" "worker" {
  count       = 3
  name        = "worker-${count.index + 1}"
  image_name  = "Ubuntu-24.04-LTS (Noble Numbat)"
  flavor_name = "aem.2c4r.50g"

  network { name = "oslomet" }

  key_pair        = "MasterVMKey"
  security_groups = ["default"]
}

# ---------------- CEPh DISKS ----------------
resource "openstack_blockstorage_volume_v3" "worker_disk" {
  count = 3
  size  = 20
}

resource "openstack_compute_volume_attach_v2" "worker_attach" {
  count       = 3
  instance_id = openstack_compute_instance_v2.worker[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.worker_disk[count.index].id

  depends_on = [
    openstack_compute_instance_v2.worker,
    openstack_blockstorage_volume_v3.worker_disk
  ]
}

# ---------------- INVENTORY GENERATION ----------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/inventory.tpl", {
    master_ip  = openstack_compute_instance_v2.master[0].access_ip_v4
    worker_ips = openstack_compute_instance_v2.worker[*].access_ip_v4
  })

  filename = "${path.module}/../ansible/inventory/inventory"

  depends_on = [
    openstack_compute_instance_v2.master,
    openstack_compute_instance_v2.worker
  ]
}

# ---------------- OUTPUTS ----------------
output "master_ip" {
  value = openstack_compute_instance_v2.master[0].access_ip_v4
}

output "worker_ips" {
  value = openstack_compute_instance_v2.worker[*].access_ip_v4
}