################################################################################
##  File:  Enable-CloudbaseInit.ps1
##  Desc:  Ensure Cloudbase-Init remains enabled in Proxmox runner images.
################################################################################

$cloudbaseService = Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue
if ($null -eq $cloudbaseService) {
    throw "Cloudbase-Init is not installed. Rebuild the Windows Proxmox base image first."
}

if (Test-Path -LiteralPath "HKLM:\SOFTWARE\Cloudbase Solutions\Cloudbase-Init") {
    Remove-Item -LiteralPath "HKLM:\SOFTWARE\Cloudbase Solutions\Cloudbase-Init" -Recurse -Force
}

$cloudbaseLogDirectory = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log"
if (Test-Path -LiteralPath $cloudbaseLogDirectory) {
    Get-ChildItem -LiteralPath $cloudbaseLogDirectory -Force | Remove-Item -Recurse -Force
}

Set-Service -Name cloudbase-init -StartupType Automatic
if ($cloudbaseService.Status -eq "Running") {
    Stop-Service -Name cloudbase-init -Force
}
