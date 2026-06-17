################################################################################
##  File:  install-cloudbase-init.ps1
##  Desc:  Install and configure Cloudbase-Init for Proxmox ConfigDrive bootstraps.
################################################################################

$ErrorActionPreference = "Stop"

function Invoke-DownloadWithRetry {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Url,
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    Write-Host "Downloading package from $Url to $Path..."

    $interval = 30
    for ($retries = 20; $retries -gt 0; $retries--) {
        try {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing
            return $Path
        } catch {
            Write-Warning $_.Exception.Message
        }

        if ($retries -eq 1) {
            throw "Package download failed: $Url"
        }

        Write-Warning "Waiting $interval seconds before retrying (retries left: $($retries - 1))..."
        Start-Sleep -Seconds $interval
    }
}

$installerUrl = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$installerPath = Join-Path $env:TEMP "CloudbaseInitSetup_Stable_x64.msi"
$installerLogPath = Join-Path $env:TEMP "cloudbase-init-msi.log"

Invoke-DownloadWithRetry -Url $installerUrl -Path $installerPath | Out-Null

Start-Process -FilePath "msiexec.exe" `
    -ArgumentList @("/i", $installerPath, "/qn", "/norestart", "/l*v", $installerLogPath) `
    -Wait `
    -NoNewWindow

$cloudbaseRoot = @(
    (Join-Path ${env:ProgramFiles} "Cloudbase Solutions\Cloudbase-Init"),
    (Join-Path ${env:ProgramFiles(x86)} "Cloudbase Solutions\Cloudbase-Init")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if (-not $cloudbaseRoot) {
    throw "Cloudbase-Init installation path was not found."
}

$configDirectory = Join-Path $cloudbaseRoot "conf"
$cloudbaseConfigPath = Join-Path $configDirectory "cloudbase-init.conf"
$cloudbaseUnattendConfigPath = Join-Path $configDirectory "cloudbase-init-unattend.conf"

Write-Host "Setting timezone to UTC"
tzutil.exe /s "UTC"

Write-Host "Disabling automatic time zone updates"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name Start -Value 4 -Force
Get-Service -Name tzautoupdate -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue

Write-Host "Disabling geolocation service"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name Status -Value 0 -Force
Get-Service -Name lfsvc -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue

$cloudbaseConfig = @'
[DEFAULT]
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin
allow_reboot=true
stop_service_on_exit=false
check_latest_version=false
first_logon_behaviour=no
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log
log_file=cloudbase-init.log
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts
process_userdata=true
inject_user_password=false

[config_drive]
types=iso,vfat
locations=cdrom,hdd,partition
'@

$cloudbaseUnattendConfig = @'
[DEFAULT]
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin
allow_reboot=true
stop_service_on_exit=false
check_latest_version=false
first_logon_behaviour=no
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log
log_file=cloudbase-init-unattend.log
inject_user_password=false

[config_drive]
types=iso,vfat
locations=cdrom,hdd,partition
'@

Set-Content -LiteralPath $cloudbaseConfigPath -Value $cloudbaseConfig -NoNewline
Set-Content -LiteralPath $cloudbaseUnattendConfigPath -Value $cloudbaseUnattendConfig -NoNewline

$cloudbaseService = Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue
if ($null -eq $cloudbaseService) {
    throw "Cloudbase-Init service was not created."
}

Set-Service -Name cloudbase-init -StartupType Automatic
if ($cloudbaseService.Status -eq "Running") {
    Stop-Service -Name cloudbase-init -Force
}
