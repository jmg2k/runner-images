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
  os                       = "win11"
  machine                  = "q35"
  bios                     = "seabios"
  scsi_controller          = "virtio-scsi-single"
  full_clone               = var.proxmox_full_clone
  cloud_init               = var.proxmox_enable_cloud_init
  cloud_init_storage_pool  = var.proxmox_cloud_init_storage_pool

  communicator             = "winrm"
  winrm_username           = var.winrm_username
  winrm_password           = var.winrm_password
  winrm_timeout            = var.winrm_timeout
  winrm_insecure           = var.winrm_insecure
  winrm_use_ssl            = false
}
