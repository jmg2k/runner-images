# Create Proxmox Base Templates

This repository can build the minimal Proxmox base templates that the runner-template flow clones later.

The intended pipeline is:

1. Start from an OS ISO.
2. Build a minimal Proxmox base template with `GenerateProxmoxBaseTemplate`.
3. Build a full runner template by cloning that base template with `GenerateProxmoxTemplate`.

The base template's job is only to provide the minimum prerequisites needed by the clone-based runner image build:

- Ubuntu 24.04:
  - installed from ISO
  - `packer` user
  - SSH enabled with password auth
  - passwordless `sudo`
  - `qemu-guest-agent`
- Windows Server 2022:
  - installed from ISO
  - local admin user for Packer
  - WinRM over HTTPS enabled
  - `qemu-guest-agent`

## ISO sources

For Ubuntu 24.04, use the official Ubuntu live server ISO. Ubuntu's release index shows `ubuntu-24.04-live-server-amd64.iso` in the 24.04 release directory:

- <https://old-releases.ubuntu.com/releases/24.04.2/>

For Windows Server 2022, use Microsoft's official evaluation ISO download:

- <https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022>

As of April 23, 2026, Microsoft's Evaluation Center says the Windows Server 2022 evaluation expires after 180 days, so for long-lived templates you'll usually want properly licensed media rather than the evaluation ISO.

## Proxmox ISO path

The helper expects the OS ISO to already exist in Proxmox storage and be referenced by datastore path, for example:

- `local:iso/ubuntu-24.04-live-server-amd64.iso`
- `local:iso/Windows_Server_2022.iso`

That matches the Proxmox builder docs for `boot_iso.iso_file`:

- <https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso>

## Usage

Import the helper:

```powershell
Import-Module .\helpers\GenerateProxmoxBaseTemplate.ps1
```

Build Ubuntu 24.04 base template:

```powershell
GenerateProxmoxBaseTemplate `
  -ImageType Ubuntu2404 `
  -ProxmoxNode pve1 `
  -IsoFile local:iso/ubuntu-24.04-live-server-amd64.iso `
  -TemplateName tmpl-ubuntu-2404-base `
  -ProxmoxStoragePool local-lvm `
  -SshUsername packer `
  -SshPassword "SomeSecurePassword1"
```

Build Windows Server 2022 base template:

```powershell
GenerateProxmoxBaseTemplate `
  -ImageType Windows2022 `
  -ProxmoxNode pve1 `
  -IsoFile local:iso/Windows_Server_2022.iso `
  -TemplateName tmpl-windows-2022-base `
  -ProxmoxStoragePool local-lvm `
  -WinRMUsername packer `
  -WinRMPassword "SomeSecurePassword1"
```

## Then build the runner template

Once the base template exists, use the clone-based helper from the other doc:

- [create-image-and-proxmox-template.md](./create-image-and-proxmox-template.md)

Example:

```powershell
GenerateProxmoxTemplate `
  -ImageType Ubuntu2404 `
  -ProxmoxNode pve1 `
  -CloneVm tmpl-ubuntu-2404-base `
  -TemplateName gha-ubuntu-2404 `
  -SshUsername packer `
  -SshPassword "SomeSecurePassword1"
```

## Notes

- The base-image builders live under `base-images/` to keep their purpose separate from the full runner image templates under `images/`.
- The Ubuntu and Windows base templates are intentionally minimal.
- The runner tools, SDKs, browsers, and large provisioning payload still come from the normal runner-image build that clones these base templates.
