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
  os                       = "l26"
  machine                  = "q35"
  bios                     = "seabios"
  scsi_controller          = "virtio-scsi-single"

  boot_iso {
    type             = "scsi"
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

  http_content = {
    "/user-data" = templatefile("${path.root}/../../http/user-data.pkrtpl.hcl", {
      ssh_username = var.ssh_username
      ssh_password = var.ssh_password
    })
    "/meta-data" = file("${path.root}/../../http/meta-data")
  }

  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  boot_wait    = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
    "<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]
}
