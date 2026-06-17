source "proxmox-iso" "base" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  node                     = var.proxmox_node
  vm_id                    = var.proxmox_vm_id
  vm_name                  = var.proxmox_vm_name
  pool                     = var.proxmox_pool
  template_name            = var.proxmox_template_name
  template_description     = var.proxmox_template_description
  task_timeout             = var.proxmox_task_timeout
  qemu_agent               = var.proxmox_qemu_agent
  cores                    = var.vm_cores
  memory                   = var.vm_memory
  cpu_type                 = "host"
  os                       = "win11"
  machine                  = "q35"
  bios                     = "seabios"
  scsi_controller          = "virtio-scsi-single"

  boot_iso {
    type             = "ide"
    iso_file         = var.iso_file
    iso_storage_pool = var.proxmox_iso_storage_pool
    iso_checksum     = var.iso_checksum
    unmount          = true
  }

  disks {
    type         = "scsi"
    storage_pool = var.proxmox_storage_pool
    disk_size    = var.disk_size
    format       = "raw"
    ssd          = true
  }

  network_adapters {
    bridge = var.proxmox_bridge
    model  = "virtio"
  }

  additional_iso_files {
    type         = "ide"
    index        = 1
    iso_file     = "local:iso/autounattend.iso"
    iso_checksum = "none"
    unmount      = true
  }

  additional_iso_files {
    type         = "ide"
    index        = 2
    iso_file     = "local:iso/virtio-win-0.1.271.iso"
    iso_checksum = "none"
    unmount      = true
  }

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = var.winrm_timeout
  winrm_insecure = true
  winrm_use_ssl  = false
  boot_wait      = "3s"

  boot_command = [
    "<enter><wait><enter><wait><enter>"
  ]
}
