source "proxmox-clone" "image" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node
  pool                     = var.proxmox_pool
  clone_vm_id              = var.proxmox_clone_vm_id
  vm_id                    = var.proxmox_vm_id
  vm_name                  = var.proxmox_vm_name != null ? var.proxmox_vm_name : "${var.proxmox_template_name}-build"
  template_name            = var.proxmox_template_name
  template_description     = var.proxmox_template_description
  task_timeout             = var.proxmox_task_timeout
  qemu_agent               = var.proxmox_qemu_agent
  cores                    = 8
  memory                   = 16384
  cpu_type                 = var.proxmox_cpu_type
  os                       = "l26"
  machine                  = "q35"
  bios                     = "seabios"
  scsi_controller          = "virtio-scsi-single"
  full_clone               = var.proxmox_full_clone
  cloud_init               = var.proxmox_enable_cloud_init
  cloud_init_storage_pool  = var.proxmox_cloud_init_storage_pool

  ssh_username             = var.ssh_username
  ssh_password             = var.ssh_password
  ssh_timeout              = var.ssh_timeout
  ssh_handshake_attempts   = var.ssh_handshake_attempts
}
