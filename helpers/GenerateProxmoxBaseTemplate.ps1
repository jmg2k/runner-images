$ErrorActionPreference = 'Stop'

enum ProxmoxBaseImageType {
    Windows2022 = 1
    Ubuntu2404  = 2
}

function Get-ProxmoxBaseTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [ProxmoxBaseImageType] $ImageType
    )

    switch ($ImageType) {
        ([ProxmoxBaseImageType]::Windows2022) {
            $relativeTemplatePath = Join-Path (Join-Path (Join-Path "windows" "templates") "proxmox") "build.windows-2022-base.pkr.hcl"
            $buildName = "windows-2022-base"
        }
        ([ProxmoxBaseImageType]::Ubuntu2404) {
            $relativeTemplatePath = Join-Path (Join-Path (Join-Path "ubuntu" "templates") "proxmox") "build.ubuntu-24_04-base.pkr.hcl"
            $buildName = "ubuntu-24_04-base"
        }
        default { throw "Unknown image type '$ImageType'." }
    }

    $templatePath = [IO.Path]::Combine($RepositoryRoot, "base-images", $relativeTemplatePath)
    if (-not (Test-Path $templatePath)) {
        throw "Base template for image '$ImageType' doesn't exist on path '$templatePath'."
    }

    return [PSCustomObject] @{
        BuildName = $buildName
        Path      = [IO.Path]::GetDirectoryName($templatePath)
    }
}

function Add-PackerBaseVarArgument {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]] $Arguments,
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    $Arguments.Add("-var=$Name=$Value")
}

function New-ProxmoxBaseTemplateWorkingDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $PackerTemplate,
        [Parameter(Mandatory = $true)]
        [ProxmoxBaseImageType] $ImageType,
        [Parameter(Mandatory = $false)]
        [string] $WinRMUsername,
        [Parameter(Mandatory = $false)]
        [string] $WinRMPassword
    )

    if ($ImageType -ne [ProxmoxBaseImageType]::Windows2022) {
        return $PackerTemplate.Path
    }

    $repoRoot = Split-Path -Parent (Split-Path -Parent $PackerTemplate.Path)
    $answerFilesPath = Join-Path $repoRoot "answer-files"
    $answerTemplatePath = Join-Path $answerFilesPath "autounattend.pkrtpl.hcl"
    $renderedAnswerPath = Join-Path $answerFilesPath "autounattend.xml"
    $sysprepTemplatePath = Join-Path $answerFilesPath "sysprep-unattend.pkrtpl.hcl"
    $renderedSysprepPath = Join-Path $answerFilesPath "sysprep-unattend.xml"
    if (-not (Test-Path -LiteralPath $answerFilesPath)) {
        New-Item -Path $answerFilesPath -ItemType Directory -Force | Out-Null
    }
    $answerContent = Get-Content -LiteralPath $answerTemplatePath -Raw
    $answerContent = $answerContent.Replace('${admin_username}', $WinRMUsername)
    $answerContent = $answerContent.Replace('${admin_password}', $WinRMPassword)
    Set-Content -LiteralPath $renderedAnswerPath -Value $answerContent -NoNewline

    $sysprepContent = Get-Content -LiteralPath $sysprepTemplatePath -Raw
    $sysprepContent = $sysprepContent.Replace('${admin_username}', $WinRMUsername)
    $sysprepContent = $sysprepContent.Replace('${admin_password}', $WinRMPassword)
    Set-Content -LiteralPath $renderedSysprepPath -Value $sysprepContent -NoNewline

    return $PackerTemplate.Path
}

function GenerateProxmoxBaseTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [ProxmoxBaseImageType] $ImageType,
        [Parameter(Mandatory = $true)]
        [string] $ProxmoxNode,
        [Parameter(Mandatory = $true)]
        [string] $IsoFile,
        [Parameter(Mandatory = $true)]
        [string] $TemplateName,
        [Parameter(Mandatory = $false)]
        [string] $ImageGenerationRepositoryRoot = $pwd,
        [Parameter(Mandatory = $true)]
        [string] $ProxmoxStoragePool,
        [Parameter(Mandatory = $false)]
        [string] $ProxmoxIsoStoragePool,
        [Parameter(Mandatory = $false)]
        [string] $ProxmoxBridge = "vmbr0",
        [Parameter(Mandatory = $false)]
        [string] $ProxmoxPool,
        [Parameter(Mandatory = $true)]
        [int] $VmId,
        [Parameter(Mandatory = $false)]
        [string] $VmName,
        [Parameter(Mandatory = $false)]
        [string] $TemplateDescription,
        [Parameter(Mandatory = $false)]
        [string] $PluginVersion = "1.2.3",
        [Parameter(Mandatory = $false)]
        [switch] $InsecureSkipTlsVerify,
        [Parameter(Mandatory = $false)]
        [string] $SshUsername,
        [Parameter(Mandatory = $false)]
        [string] $SshPassword,
        [Parameter(Mandatory = $false)]
        [string] $WinRMUsername,
        [Parameter(Mandatory = $false)]
        [string] $WinRMPassword
    )

    $PackerBinary = Get-Command "packer" -ErrorAction SilentlyContinue
    if (-not $PackerBinary) {
        throw "'packer' binary is not found on PATH."
    }

    $PackerTemplate = Get-ProxmoxBaseTemplate -RepositoryRoot $ImageGenerationRepositoryRoot -ImageType $ImageType
    $WorkingTemplatePath = $null

    $validateArgs = [System.Collections.Generic.List[string]]::new()
    $validateArgs.Add("validate")
    $validateArgs.Add("-only")
    $validateArgs.Add("$($PackerTemplate.BuildName)*")

    $buildArgs = [System.Collections.Generic.List[string]]::new()
    $buildArgs.Add("build")
    $buildArgs.Add("-only")
    $buildArgs.Add("$($PackerTemplate.BuildName)*")

    foreach ($argumentSet in @($validateArgs, $buildArgs)) {
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_node" -Value $ProxmoxNode
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_storage_pool" -Value $ProxmoxStoragePool
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_iso_storage_pool" -Value $ProxmoxIsoStoragePool
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_bridge" -Value $ProxmoxBridge
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_pool" -Value $ProxmoxPool
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_vm_id" -Value $VmId
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_vm_name" -Value $VmName
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_template_name" -Value $TemplateName
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_template_description" -Value $TemplateDescription
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "proxmox_insecure_skip_tls_verify" -Value $InsecureSkipTlsVerify.IsPresent.ToString().ToLowerInvariant()
        Add-PackerBaseVarArgument -Arguments $argumentSet -Name "iso_file" -Value $IsoFile
    }

    switch ($ImageType) {
        ([ProxmoxBaseImageType]::Ubuntu2404) {
            if ([string]::IsNullOrWhiteSpace($SshUsername) -or [string]::IsNullOrWhiteSpace($SshPassword)) {
                throw "SshUsername and SshPassword are required for Ubuntu2404."
            }

            foreach ($argumentSet in @($validateArgs, $buildArgs)) {
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "ssh_username" -Value $SshUsername
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "ssh_password" -Value $SshPassword
            }
        }
        ([ProxmoxBaseImageType]::Windows2022) {
            if ([string]::IsNullOrWhiteSpace($WinRMUsername) -or [string]::IsNullOrWhiteSpace($WinRMPassword)) {
                throw "WinRMUsername and WinRMPassword are required for Windows2022."
            }

            foreach ($argumentSet in @($validateArgs, $buildArgs)) {
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "winrm_username" -Value $WinRMUsername
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "winrm_password" -Value $WinRMPassword
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "admin_username" -Value $WinRMUsername
                Add-PackerBaseVarArgument -Arguments $argumentSet -Name "admin_password" -Value $WinRMPassword
            }
        }
    }

    $WorkingTemplatePath = New-ProxmoxBaseTemplateWorkingDirectory `
        -PackerTemplate $PackerTemplate `
        -ImageType $ImageType `
        -WinRMUsername $WinRMUsername `
        -WinRMPassword $WinRMPassword

    try {
        $validateArgs.Add($WorkingTemplatePath)
        $buildArgs.Add($WorkingTemplatePath)

        Write-Host "Downloading packer plugins..."
        & $PackerBinary plugins install github.com/hashicorp/proxmox $PluginVersion
        if ($LastExitCode -ne 0) {
            throw "Packer plugin download failed."
        }

        Write-Host "Validating Proxmox base template..."
        & $PackerBinary @validateArgs
        if ($LastExitCode -ne 0) {
            throw "Packer template validation failed."
        }

        Write-Host "Building Proxmox base template..."
        & $PackerBinary @buildArgs
        if ($LastExitCode -ne 0) {
            throw "Packer build failed."
        }
    }
    finally {
        if ($ImageType -eq [ProxmoxBaseImageType]::Windows2022) {
            $repoRoot = Split-Path -Parent (Split-Path -Parent $PackerTemplate.Path)
            $renderedAnswerPath = Join-Path $repoRoot "answer-files\autounattend.xml"
            $renderedSysprepPath = Join-Path $repoRoot "answer-files\sysprep-unattend.xml"
            if (Test-Path -LiteralPath $renderedAnswerPath) {
                Remove-Item -LiteralPath $renderedAnswerPath -Force
            }
            if (Test-Path -LiteralPath $renderedSysprepPath) {
                Remove-Item -LiteralPath $renderedSysprepPath -Force
            }
        }

        if ($WorkingTemplatePath -and $WorkingTemplatePath -ne $PackerTemplate.Path -and (Test-Path -LiteralPath $WorkingTemplatePath)) {
            Remove-Item -LiteralPath $WorkingTemplatePath -Recurse -Force
        }
    }
}
