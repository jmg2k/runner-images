build {
  name    = "windows-2022-base"
  sources = ["source.proxmox-iso.base"]

  provisioner "file" {
    source      = "${path.root}/../../answer-files/sysprep-unattend.xml"
    destination = "C:\\Windows\\System32\\Sysprep\\unattend.xml"
  }

  provisioner "file" {
    source      = "${path.root}/../../answer-files/install-cloudbase-init.ps1"
    destination = "C:\\Windows\\Temp\\install-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    inline = [
      "& C:\\Windows\\Temp\\install-cloudbase-init.ps1"
    ]
  }

  provisioner "powershell" {
    inline = [
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /mode:vm /quiet /quit /unattend:$env:SystemRoot\\System32\\Sysprep\\unattend.xml",
      "while($true) { $imageState = (Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State').ImageState; if($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }; Start-Sleep -Seconds 10 }"
    ]
  }
}
