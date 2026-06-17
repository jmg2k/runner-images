################################################################################
##  File:  Configure-BaseImage.ps1
##  Desc:  Prepare the base image for software installation
################################################################################

function Disable-InternetExplorerESC {
    $adminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $userKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $adminKey -Name "IsInstalled" -Value 0 -Force
    Set-ItemProperty -Path $userKey -Name "IsInstalled" -Value 0 -Force

    $ieProcess = Get-Process -Name Explorer -ErrorAction SilentlyContinue

    if ($ieProcess) {
        Stop-Process -Name Explorer -Force -ErrorAction Continue
    }

    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled."
}

function Disable-InternetExplorerWelcomeScreen {
    $adminKey = "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main"
    New-Item -Path $adminKey -Value 1 -Force
    Set-ItemProperty -Path $adminKey -Name "DisableFirstRunCustomize" -Value 1 -Force
    Write-Host "Disabled IE Welcome screen"
}

function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000 -Force
    Write-Host "User Access Control (UAC) has been disabled."
}

function Disable-WindowsUpdate {
    $autoUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (Test-Path -Path $autoUpdatePath) {
        Set-ItemProperty -Path $autoUpdatePath -Name NoAutoUpdate -Value 1
        Write-Host "Disabled Windows Update"
    } else {
        Write-Host "Windows Update key does not exist"
    }
}

function Set-UtcTimeZone {
    Write-Host "Setting timezone to UTC"
    tzutil.exe /s "UTC"

    Write-Host "Disabling automatic time zone updates"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name Start -Value 4 -Force
    Get-Service -Name tzautoupdate -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue

    Write-Host "Disabling geolocation service"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name Status -Value 0 -Force
    Get-Service -Name lfsvc -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
}

# Enable $ErrorActionPreference='Stop' for AllUsersAllHosts
Add-Content -Path $profile.AllUsersAllHosts -Value '$ErrorActionPreference="Stop"'

Write-Host "Disable Server Manager on Logon"
Get-ScheduledTask -TaskName ServerManager -ErrorAction SilentlyContinue | Disable-ScheduledTask

Write-Host "Disable 'Allow your PC to be discoverable by other PCs' popup"
New-Item -Path HKLM:\System\CurrentControlSet\Control\Network -Name NewNetworkWindowOff -Force

Write-Host 'Disable Windows Update Medic Service'
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\WaaSMedicSvc -Name Start -Value 4 -Force

Write-Host "Disable Windows Update"
Disable-WindowsUpdate

Set-UtcTimeZone

Write-Host "Disable UAC"
Disable-UserAccessControl

Write-Host "Disable IE Welcome Screen"
Disable-InternetExplorerWelcomeScreen

Write-Host "Disable IE ESC"
Disable-InternetExplorerESC

Write-Host "Setting local execution policy"
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -ErrorAction Continue | Out-Null
Get-ExecutionPolicy -List

Write-Host "Enable long path behavior"
# See https://docs.microsoft.com/en-us/windows/desktop/fileio/naming-a-file#maximum-path-length-limitation
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1

# Expand disk size of OS drive
$driveLetter = "C"
$size = Get-PartitionSupportedSize -DriveLetter $driveLetter
$partition = Get-Partition -DriveLetter $driveLetter
$minimumGrowthBytes = 1MB

if ($null -eq $partition -or $null -eq $size) {
    Write-Host "Skipping OS drive resize because partition information for $driveLetter was not available."
} elseif (($size.SizeMax - $partition.Size) -lt $minimumGrowthBytes) {
    Write-Host "Skipping OS drive resize because the remaining extendable space is less than 1 MB."
} else {
    Resize-Partition -DriveLetter $driveLetter -Size $size.SizeMax
}

Get-Volume | Select-Object DriveLetter, SizeRemaining, Size | Sort-Object DriveLetter
