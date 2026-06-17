#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ubuntu2404-proxmox-base
    username: ${ssh_username}
    password: "$6$rounds=4096$placeholder$bpN3yVY1VYg5fK5dAWF4LQw8P9GvXx9YvKJ2Zc0xYVxSxkQ2N5l9W6tLrR1Ew9px5j4kW8Q0nH4MZlQzGm9M6."
  ssh:
    allow-pw: true
    install-server: true
  packages:
    - qemu-guest-agent
    - sudo
    - curl
  late-commands:
    - curtin in-target --target=/target -- usermod -aG sudo ${ssh_username}
    - curtin in-target --target=/target -- bash -c "echo '${ssh_username}:${ssh_password}' | chpasswd"
    - curtin in-target --target=/target -- bash -c "echo '${ssh_username} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${ssh_username}"
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${ssh_username}
    - curtin in-target --target=/target -- systemctl enable ssh
    - curtin in-target --target=/target -- systemctl enable qemu-guest-agent
    - curtin in-target --target=/target -- sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    - curtin in-target --target=/target -- sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
