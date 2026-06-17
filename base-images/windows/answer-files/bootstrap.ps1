param (
    [string]$AdminUsername = "packer"
)

# 1. Install VirtIO Guest Tools (For IP reporting to Proxmox)
Write-Output "Searching for VirtIO Guest Tools..."
$drive = (Get-PSDrive | Where-Object { Test-Path ($_.Root + "virtio-win-guest-tools.exe") }).Root
if ($drive) {
    Write-Output "Installing VirtIO Guest Tools from ${drive}..."
    Start-Process ($drive + "virtio-win-guest-tools.exe") -ArgumentList '/install', '/quiet', '/norestart' -Wait
}

# 2. Network Configuration
# Wait a moment for Guest Agent/Drivers to settle
Start-Sleep -s 15
Write-Output "Setting Network Category to Private..."
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# 3. Configure WinRM
Write-Output "Configuring WinRM..."
Enable-PSRemoting -Force
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Create HTTPS Listener
$cert = New-SelfSignedCertificate -DnsName "packer" -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"packer`"; CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# 4. Firewall Rules
Write-Output "Opening Firewall Ports..."
netsh advfirewall firewall add rule name='WinRM 5985' dir=in action=allow protocol=TCP localport=5985
netsh advfirewall firewall add rule name='WinRM 5986' dir=in action=allow protocol=TCP localport=5986

# 5. Disable Password Expiration
Write-Output "Disabling password expiration for $AdminUsername..."
wmic useraccount where "name='$AdminUsername'" set PasswordExpires=FALSE