# GitHub Actions Runner Images on Proxmox

This repository can also provision runner images on Proxmox by using Packer's `proxmox-clone` builder instead of the Azure builder used by the default workflow.

The Proxmox path in this repository is intentionally based on cloning an existing, clean base template:

- `Ubuntu2404` builds from a prepared Ubuntu 24.04 Proxmox template.
- `Windows2022` builds from a prepared Windows Server 2022 Proxmox template.

This keeps the runner-image provisioning payload from this repository intact and only swaps the infrastructure target. The Proxmox helper stages a temporary Packer working directory from the existing upstream template files, so later upstream diffs stay concentrated in the original template files rather than a second copied build tree.

- [Why clone-based builds](#why-clone-based-builds)
- [Build agent preparation](#build-agent-preparation)
- [Prepare Proxmox base templates](#prepare-proxmox-base-templates)
- [Manual image generation](#manual-image-generation)
- [Deploy a runner VM from the resulting template](#deploy-a-runner-vm-from-the-resulting-template)
- [Notes and limitations](#notes-and-limitations)

## Why clone-based builds

The upstream templates in this repository assume Packer can already reach a running OS over SSH or WinRM. Because of that, the Proxmox integration here uses `proxmox-clone` rather than `proxmox-iso`.

HashiCorp documents both Proxmox builders:

- `proxmox-clone`: <https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/clone>
- `proxmox-iso`: <https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso>

The clone builder requires a base template to already exist in Proxmox, and it can convert the provisioned result back into a new template.

## Build agent preparation

Use any Windows or Linux machine that can reach both your Proxmox API and the temporary build VM.

Install:

- Packer
- Git
- PowerShell 5.1 or newer

The Proxmox plugin must also be available to Packer. The helper script added in this repository installs it automatically:

```powershell
packer plugins install github.com/hashicorp/proxmox 1.2.3
```

The plugin source and builder details come from the official HashiCorp docs:

- <https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox>

Set these environment variables for Proxmox authentication if you do not want to pass credentials interactively:

```powershell
$env:PROXMOX_URL = "https://proxmox.example.com:8006/api2/json"
$env:PROXMOX_USERNAME = "packer@pve!gha"
$env:PROXMOX_TOKEN = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

`PROXMOX_PASSWORD` can be used instead of `PROXMOX_TOKEN`, but token auth is usually the cleaner fit for automation.

Many image provisioning scripts query GitHub Releases. If your build agent or Proxmox guest egress IP hits GitHub's unauthenticated API rate limit, set `GITHUB_TOKEN` on the build agent or pass `-GitHubToken` to the helper:

```powershell
$env:GITHUB_TOKEN = "github_pat_or_fine_grained_token"
```

The token is passed to Packer as a sensitive variable and exposed to installer provisioners as `GITHUB_TOKEN`.

## Prepare Proxmox base templates

### Ubuntu 24.04 base template

Your base template should already be able to accept SSH connections from Packer and should have:

- OpenSSH installed and reachable on the network used by Proxmox
- a `packer` user with password authentication enabled
- passwordless `sudo` for that user
- `qemu-guest-agent` installed and running
- enough disk space for the full runner image build
- optional `cloud-init` if you want cloned runner VMs to consume cloud-init later

### Windows Server 2022 base template

Your base template should already be able to accept WinRM over HTTPS and should have:

- a local administrator account such as `packer`
- WinRM HTTPS enabled for that account
- QEMU guest agent installed and running
- VirtIO drivers installed if your template depends on them
- enough free disk space for the full runner image build

The Proxmox clone builder can discover the guest IP through QEMU Guest Agent when `qemu_agent` is enabled in the Packer source. That is how the Proxmox templates in this repo are wired.

## Manual image generation

Import the helper:

```powershell
Import-Module .\helpers\GenerateProxmoxTemplate.ps1
```

Build Ubuntu 24.04:

```powershell
GenerateProxmoxTemplate `
  -ImageType Ubuntu2404 `
  -ProxmoxNode pve1 `
  -CloneVmId 9001 `
  -VmId 9101 `
  -TemplateName gha-ubuntu-2404 `
  -SshUsername packer `
  -SshPassword "SomeSecurePassword1" `
  -GitHubToken $env:GITHUB_TOKEN
```

Build Windows Server 2022:

```powershell
GenerateProxmoxTemplate `
  -ImageType Windows2022 `
  -ProxmoxNode pve1 `
  -CloneVmId 9002 `
  -VmId 9102 `
  -TemplateName gha-windows-2022 `
  -WinRMUsername packer `
  -WinRMPassword "SomeSecurePassword1" `
  -InstallPassword "AnotherSecurePassword1" `
  -GitHubToken $env:GITHUB_TOKEN
```

Optional parameters:

- `-ProxmoxPool` to place the VM/template in a pool
- `-CloneVmId` to select the source base template by VMID instead of name
- `-VmName` to control the temporary build VM name
- `-TemplateDescription` to label the final template
- `-InsecureSkipTlsVerify` if you are using self-signed Proxmox TLS and have not installed the CA on the build agent
- `-GitHubToken` to authenticate GitHub Releases API calls during provisioning and avoid unauthenticated rate limits. If omitted, the helper uses `$env:GITHUB_TOKEN` when present.

## Deploy a runner VM from the resulting template

After the build finishes, Proxmox will contain a new template such as `gha-ubuntu-2404` or `gha-windows-2022`.

The usual next step is:

1. Clone that template into a normal VM in Proxmox.
2. Give the VM the CPU, memory, and disk sizing you want for your self-hosted runner fleet.
3. Install and register the GitHub Actions runner service on first boot.

For GitHub self-hosted runner setup, use the GitHub documentation:

- <https://docs.github.com/en/actions/hosting-your-own-runners>

## Notes and limitations

- The Proxmox path added here currently targets `Ubuntu2404` and `Windows2022`.
- These builds preserve the existing runner-images provisioning logic, but they do not recreate Azure managed-image behavior.
- Disk and low-level hardware shape come from your Proxmox base template. The clone builder docs note that specifying disks on `proxmox-clone` replaces the cloned VM disks, so these templates intentionally reuse the base template disk layout instead of redefining it.
