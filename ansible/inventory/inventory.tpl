all:
  vars:
    ansible_user: ubuntu
    ansible_become: true
    ansible_become_method: sudo
    ansible_ssh_private_key_file: /home/ubuntu/.ssh/id_ed25519
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  hosts:
    master:
      ansible_host: ${master_ip}
      ip: ${master_ip}
      access_ip: ${master_ip}
      etcd_member_name: etcd1

    worker-1:
      ansible_host: ${worker_ips[0]}
      ip: ${worker_ips[0]}
      access_ip: ${worker_ips[0]}

    worker-2:
      ansible_host: ${worker_ips[1]}
      ip: ${worker_ips[1]}
      access_ip: ${worker_ips[1]}

    worker-3:
      ansible_host: ${worker_ips[2]}
      ip: ${worker_ips[2]}
      access_ip: ${worker_ips[2]}

  children:
    kube_control_plane:
      hosts:
        master:

    kube_node:
      hosts:
        worker-1:
        worker-2:
        worker-3:

    etcd:
      hosts:
        master:

    k8s_cluster:
      children:
        kube_control_plane:
        kube_node: