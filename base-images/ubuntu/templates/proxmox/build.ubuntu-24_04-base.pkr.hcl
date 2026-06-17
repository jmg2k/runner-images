build {
  name    = "ubuntu-24_04-base"
  sources = ["source.proxmox-iso.base"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "sudo timedatectl set-timezone UTC",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent",
      "sudo truncate -s 0 /etc/machine-id || true",
      "sudo rm -f /var/lib/dbus/machine-id || true",
      "sudo rm -f /etc/ssh/ssh_host_* || true",
      "sudo cloud-init clean --logs --seed || true",
      "sync"
    ]
  }
}
