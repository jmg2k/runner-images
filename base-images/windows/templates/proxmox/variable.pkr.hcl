variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_URL")
}

variable "proxmox_username" {
  type    = string
  default = env("PROXMOX_USERNAME")
}

variable "proxmox_password" {
  type      = string
  default   = env("PROXMOX_PASSWORD")
  sensitive = true
}

variable "proxmox_token" {
  type      = string
  default   = env("PROXMOX_TOKEN")
  sensitive = true
}

variable "proxmox_insecure_skip_tls_verify" {
  type    = bool
  default = false
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_storage_pool" {
  type = string
}

variable "proxmox_iso_storage_pool" {
  type    = string
  default = "local"
}

variable "proxmox_bridge" {
  type    = string
  default = "vmbr0"
}

variable "proxmox_pool" {
  type    = string
  default = null
}

variable "proxmox_vm_id" {
  type    = number
  default = null
}

variable "proxmox_vm_name" {
  type    = string
  default = "windows-2022-base-build"
}

variable "proxmox_template_name" {
  type = string
}

variable "proxmox_template_description" {
  type    = string
  default = "Minimal Windows Server 2022 base template for runner image builds"
}

variable "proxmox_task_timeout" {
  type    = string
  default = "4h"
}

variable "proxmox_qemu_agent" {
  type    = bool
  default = true
}

variable "iso_file" {
  type = string
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "vm_cores" {
  type    = number
  default = 8
}

variable "vm_memory" {
  type    = number
  default = 16384
}

variable "disk_size" {
  type    = string
  default = "256G"
}

variable "admin_username" {
  type    = string
  default = "packer"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "winrm_username" {
  type    = string
  default = "packer"
}

variable "winrm_password" {
  type      = string
  sensitive = true
}

variable "winrm_timeout" {
  type    = string
  default = "2h"
}
