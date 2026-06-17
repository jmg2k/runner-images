$ErrorActionPreference = 'Stop'

enum ProxmoxImageType {
    Windows2022 = 1
    Ubuntu2404  = 2
}

function Get-ProxmoxPackerTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [ProxmoxImageType] $ImageType
    )

    switch ($ImageType) {
        ([ProxmoxImageType]::Windows2022) {
            $relativeTemplatePath = Join-Path (Join-Path "windows" "templates") "build.windows-2022.pkr.hcl"
            $buildName = "windows-2022-proxmox"
            $templateKind = "windows"
        }
        ([ProxmoxImageType]::Ubuntu2404) {
            $relativeTemplatePath = Join-Path (Join-Path "ubuntu" "templates") "build.ubuntu-24_04.pkr.hcl"
            $buildName = "ubuntu-24_04-proxmox"
            $templateKind = "ubuntu"
        }
        default { throw "Unknown image type '$ImageType'." }
    }

    $templatePath = [IO.Path]::Combine($RepositoryRoot, "images", $relativeTemplatePath)
    if (-not (Test-Path $templatePath)) {
        throw "Template for image '$ImageType' doesn't exist on path '$templatePath'."
    }

    return [PSCustomObject] @{
        BuildName     = $buildName
        Path          = $templatePath
        DirectoryPath = [IO.Path]::GetDirectoryName($templatePath)
        TemplateKind  = $templateKind
    }
}

function Add-PackerVarArgument {
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

function New-ProxmoxTemplateDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $PackerTemplate,
        [Parameter(Mandatory = $false)]
        [string] $WinRMUsername,
        [Parameter(Mandatory = $false)]
        [string] $WinRMPassword
    )

    $imagesRoot = Split-Path -Parent (Split-Path -Parent $PackerTemplate.DirectoryPath)
    $repositoryRoot = Split-Path -Parent $imagesRoot
    $imageRoot = Split-Path -Parent $PackerTemplate.DirectoryPath
    $imageRootName = [IO.Path]::GetFileName($imageRoot)

    $stagingRoot = Join-Path $repositoryRoot (Join-Path ".tmp" ("runner-images-proxmox-" + [System.Guid]::NewGuid().ToString("N")))
    $stagedImageRoot = Join-Path $stagingRoot (Join-Path "images" $imageRootName)
    $stagedTemplateDir = Join-Path $stagedImageRoot "templates"
    New-Item -Path $stagedTemplateDir -ItemType Directory -Force | Out-Null

    foreach ($relativeDirectory in @("assets", "scripts", "toolsets")) {
        Copy-Item `
            -LiteralPath (Join-Path $imageRoot $relativeDirectory) `
            -Destination (Join-Path $stagedImageRoot $relativeDirectory) `
            -Recurse `
            -Force
    }

    Copy-Item `
        -LiteralPath (Join-Path $repositoryRoot "helpers\software-report-base") `
        -Destination (Join-Path $stagingRoot "helpers\software-report-base") `
        -Recurse `
        -Force

    $templateFilesToCopy = @(
        [IO.Path]::GetFileName($PackerTemplate.Path),
        "locals.$($PackerTemplate.TemplateKind).pkr.hcl",
        "variable.$($PackerTemplate.TemplateKind).pkr.hcl",
        "source.$($PackerTemplate.TemplateKind).pkr.hcl"
    )

    foreach ($templateFile in $templateFilesToCopy) {
        Copy-Item `
            -LiteralPath (Join-Path $PackerTemplate.DirectoryPath $templateFile) `
            -Destination (Join-Path $stagedTemplateDir $templateFile) `
            -Force
    }

    if ($PackerTemplate.TemplateKind -eq "windows") {
        $payloadDirectory = Join-Path $stagedTemplateDir ".tmp"
        $payloadArchivePath = Join-Path $payloadDirectory "payload.zip"
        New-Item -Path $payloadDirectory -ItemType Directory -Force | Out-Null
        Compress-Archive `
            -Path @(
                (Join-Path $stagedImageRoot "assets"),
                (Join-Path $stagedImageRoot "scripts"),
                (Join-Path $stagedImageRoot "toolsets")
            ) `
            -DestinationPath $payloadArchivePath `
            -Force

        $baseImagesAnswerRoot = Join-Path $stagingRoot "base-images\windows\answer-files"
        New-Item -Path $baseImagesAnswerRoot -ItemType Directory -Force | Out-Null

        $sysprepTemplatePath = Join-Path $repositoryRoot "base-images\windows\answer-files\sysprep-unattend.pkrtpl.hcl"
        $stagedSysprepPath = Join-Path $baseImagesAnswerRoot "sysprep-unattend.xml"
        $sysprepContent = Get-Content -LiteralPath $sysprepTemplatePath -Raw
        $sysprepContent = $sysprepContent.Replace('${admin_username}', $WinRMUsername)
        $sysprepContent = $sysprepContent.Replace('${admin_password}', $WinRMPassword)
        Set-Content -LiteralPath $stagedSysprepPath -Value $sysprepContent -NoNewline
    }

    return [PSCustomObject] @{
        RootPath     = $stagingRoot
        TemplatePath = $stagedTemplateDir
    }
}

function GenerateProxmoxTemplate {
    <#
        .SYNOPSIS
            Builds a runner image template on Proxmox using an existing VM template as the base.
        .DESCRIPTION
            This helper uses the Packer proxmox-clone builder. It clones a prepared Ubuntu or Windows base
            template in Proxmox, runs the provisioning payload from this repository, and converts the result
            back into a reusable Proxmox template.
        .PARAMETER ImageType
            Supported values are Windows2022 and Ubuntu2404.
        .PARAMETER ProxmoxNode
            The Proxmox node where the build VM should run.
        .PARAMETER CloneVmId
            The VMID of the clean source template to clone in Proxmox.
        .PARAMETER TemplateName
            The name of the resulting template in Proxmox.
        .PARAMETER ImageGenerationRepositoryRoot
            The root directory of the image generation repository.
        .PARAMETER ProxmoxPool
            Optional Proxmox pool name.
        .PARAMETER VmId
            Fixed VMID for the build/template artifact.
        .PARAMETER VmName
            Optional temporary VM name used during the build.
        .PARAMETER TemplateDescription
            Optional description for the final template.
        .PARAMETER PluginVersion
            Version of the Packer Proxmox plugin to install. Default is 1.2.3.
        .PARAMETER InsecureSkipTlsVerify
            Skip TLS verification for the Proxmox API connection.
        .PARAMETER SshUsername
            Ubuntu base template SSH username.
        .PARAMETER SshPassword
            Ubuntu base template SSH password.
        .PARAMETER WinRMUsername
            Windows base template WinRM username.
        .PARAMETER WinRMPassword
            Windows base template WinRM password.
        .PARAMETER InstallPassword
            Password used for the temporary installer account created during Windows image generation.
        .PARAMETER LinkedClone
            Uses a linked clone instead of a full clone for the Proxmox build VM.
        .PARAMETER CpuType
            Proxmox CPU type for the generated clone source. Defaults to host.
        .PARAMETER GitHubToken
            Optional GitHub API token passed to image provisioning scripts as GITHUB_TOKEN to raise release API rate limits.
        .EXAMPLE
            Import-Module .\helpers\GenerateProxmoxTemplate.ps1
            GenerateProxmoxTemplate -ImageType Ubuntu2404 -ProxmoxNode pve1 -CloneVmId 9001 -VmId 9101 -TemplateName gha-ubuntu-2404 -SshUsername packer -SshPassword SomeSecurePassword1
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ProxmoxImageType] $ImageType,
        [Parameter(Mandatory = $true)]
        [string] $ProxmoxNode,
        [Parameter(Mandatory = $true)]
        [int] $CloneVmId,
        [Parameter(Mandatory = $true)]
        [string] $TemplateName,
        [Parameter(Mandatory = $false)]
        [string] $ImageGenerationRepositoryRoot = $pwd,
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
        [string] $WinRMPassword,
        [Parameter(Mandatory = $false)]
        [string] $InstallPassword,
        [Parameter(Mandatory = $false)]
        [switch] $LinkedClone,
        [Parameter(Mandatory = $false)]
        [string] $CpuType = "host",
        [Parameter(Mandatory = $false)]
        [string] $GitHubToken = $env:GITHUB_TOKEN
    )

    $PackerBinary = Get-Command "packer" -ErrorAction SilentlyContinue
    if (-not $PackerBinary) {
        throw "'packer' binary is not found on PATH."
    }

    # Retrieve template metadata based on ImageType
    $PackerTemplate = Get-ProxmoxPackerTemplate -RepositoryRoot $ImageGenerationRepositoryRoot -ImageType $ImageType
    
    $WorkingTemplate = $null

    try {
        # Stage a Proxmox-specific working template so Packer sees a single template path
        # and does not load the original cloud-provider source file.
        $WorkingTemplate = New-ProxmoxTemplateDirectory `
            -PackerTemplate $PackerTemplate `
            -WinRMUsername $WinRMUsername `
            -WinRMPassword $WinRMPassword
        Write-Host "Generated Proxmox working template: $($WorkingTemplate.TemplatePath)"

        # 3. Setup Arguments
        $validateArgs = [System.Collections.Generic.List[string]]::new()
        $validateArgs.Add("validate")
        $validateArgs.Add("-only")
        $validateArgs.Add("$($PackerTemplate.BuildName)*")

        $buildArgs = [System.Collections.Generic.List[string]]::new()
        $buildArgs.Add("build")
        $buildArgs.Add("-only")
        $buildArgs.Add("$($PackerTemplate.BuildName)*")

        foreach ($argumentSet in @($validateArgs, $buildArgs)) {
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_node" -Value $ProxmoxNode
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_pool" -Value $ProxmoxPool
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_clone_vm_id" -Value $CloneVmId
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_vm_id" -Value $VmId
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_vm_name" -Value $VmName
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_template_name" -Value $TemplateName
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_template_description" -Value $TemplateDescription
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_insecure_skip_tls_verify" -Value $InsecureSkipTlsVerify.IsPresent.ToString().ToLowerInvariant()
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_full_clone" -Value (-not $LinkedClone.IsPresent).ToString().ToLowerInvariant()
            Add-PackerVarArgument -Arguments $argumentSet -Name "proxmox_cpu_type" -Value $CpuType
            Add-PackerVarArgument -Arguments $argumentSet -Name "github_token" -Value $GitHubToken
            
            switch ($ImageType) {
                ([ProxmoxImageType]::Windows2022) { 
                    Add-PackerVarArgument -Arguments $argumentSet -Name "image_os" -Value "win22" 
                }
                ([ProxmoxImageType]::Ubuntu2404)  { 
                    Add-PackerVarArgument -Arguments $argumentSet -Name "image_os" -Value "ubuntu24" 
                }
            }
        }

        switch ($ImageType) {
            ([ProxmoxImageType]::Ubuntu2404) {
                if ([string]::IsNullOrWhiteSpace($SshUsername) -or [string]::IsNullOrWhiteSpace($SshPassword)) {
                    throw "SshUsername and SshPassword are required for Ubuntu2404."
                }
                foreach ($argumentSet in @($validateArgs, $buildArgs)) {
                    Add-PackerVarArgument -Arguments $argumentSet -Name "ssh_username" -Value $SshUsername
                    Add-PackerVarArgument -Arguments $argumentSet -Name "ssh_password" -Value $SshPassword
                }
            }
            ([ProxmoxImageType]::Windows2022) {
                if ([string]::IsNullOrWhiteSpace($WinRMUsername) -or [string]::IsNullOrWhiteSpace($WinRMPassword)) {
                    throw "WinRMUsername and WinRMPassword are required for Windows2022."
                }
                if ([string]::IsNullOrWhiteSpace($InstallPassword)) {
                    $InstallPassword = $env:UserName + [System.GUID]::NewGuid().ToString().ToUpper()
                }
                foreach ($argumentSet in @($validateArgs, $buildArgs)) {
                    Add-PackerVarArgument -Arguments $argumentSet -Name "temp_dir" -Value "C:\temp"
                    Add-PackerVarArgument -Arguments $argumentSet -Name "winrm_username" -Value $WinRMUsername
                    Add-PackerVarArgument -Arguments $argumentSet -Name "winrm_password" -Value $WinRMPassword
                    Add-PackerVarArgument -Arguments $argumentSet -Name "install_password" -Value $InstallPassword
                }
            }
        }

        $validateArgs.Add($WorkingTemplate.TemplatePath)
        $buildArgs.Add($WorkingTemplate.TemplatePath)

        # 4. Execution
        Write-Host "Downloading packer plugins..."
        & $PackerBinary plugins install github.com/hashicorp/proxmox $PluginVersion
        if ($LastExitCode -ne 0) { throw "Packer plugin download failed." }

        Write-Host "Validating Proxmox template..."
        & $PackerBinary @validateArgs
        if ($LastExitCode -ne 0) { throw "Packer template validation failed." }

        Write-Host "Building Proxmox template..."
        & $PackerBinary @buildArgs
        if ($LastExitCode -ne 0) { throw "Packer build failed." }
    }
    finally {
        if ($WorkingTemplate -and (Test-Path -LiteralPath $WorkingTemplate.RootPath)) {
            Remove-Item -LiteralPath $WorkingTemplate.RootPath -Recurse -Force
        }
    }
}
