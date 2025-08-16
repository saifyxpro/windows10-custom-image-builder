@echo off
REM Windows 10 Service Configuration for Cloud Deployment
REM Run as Administrator during image preparation

echo Configuring Windows Services for Cloud Performance...

REM Set essential services to automatic
sc config "DHCP Client" start= auto
sc config "DNS Client" start= auto
sc config "Windows Update" start= auto
sc config "Windows Time" start= auto
sc config "Remote Desktop Services" start= auto
sc config "Terminal Services" start= auto
sc config "Windows Firewall" start= auto
sc config "Base Filtering Engine" start= auto
sc config "Windows Audio" start= auto
sc config "Plug and Play" start= auto
sc config "Server" start= auto
sc config "Workstation" start= auto

REM Disable unnecessary services for cloud deployment
sc config "Fax" start= disabled
sc config "Windows Search" start= manual
sc config "Superfetch" start= disabled
sc config "Themes" start= manual
sc config "Windows Audio Endpoint Builder" start= manual
sc config "Windows Audio" start= manual
sc config "Tablet PC Input Service" start= disabled
sc config "Touch Keyboard and Handwriting Panel Service" start= disabled
sc config "Windows Biometric Service" start= disabled
sc config "Windows CardSpace" start= disabled
sc config "Windows Color System" start= manual
sc config "Windows Connect Now - Config Registrar" start= manual
sc config "Windows Error Reporting Service" start= manual
sc config "Windows Event Collector" start= manual
sc config "Windows Media Player Network Sharing Service" start= disabled
sc config "Windows Mobile Hotspot Service" start= disabled
sc config "Windows Presentation Foundation Font Cache 3.0.0.0" start= manual
sc config "Windows Push Notifications System Service" start= manual
sc config "Windows Remote Management (WS-Management)" start= manual
sc config "Windows Update Medic Service" start= manual

REM Xbox-related services (disable for server use)
sc config "XblAuthManager" start= disabled
sc config "XblGameSave" start= disabled
sc config "XboxNetApiSvc" start= disabled
sc config "XboxGipSvc" start= disabled

REM OneDrive sync (disable for cloud deployment)
sc config "OneSyncSvc" start= disabled

REM Windows Defender (can be re-enabled after deployment)
sc config "WinDefend" start= manual
sc config "SecurityHealthService" start= manual
sc config "WdNisSvc" start= manual

REM Optimize memory management
sc config "SysMain" start= disabled

REM Configure network services
sc config "Netlogon" start= manual
sc config "Network Location Awareness" start= auto
sc config "Network List Service" start= manual
sc config "Network Setup Service" start= manual
sc config "Network Store Interface Service" start= auto

REM Configure print services (disable for headless deployment)
sc config "Print Spooler" start= manual

REM Configure remote services
sc config "Remote Desktop Configuration" start= auto
sc config "Remote Desktop Services UserMode Port Redirector" start= manual
sc config "Remote Procedure Call (RPC)" start= auto
sc config "RPC Endpoint Mapper" start= auto

REM Configure storage services
sc config "Storage Service" start= auto
sc config "Virtual Disk" start= auto
sc config "Volume Shadow Copy" start= manual

REM Configure time service for cloud sync
sc config "Windows Time" start= auto
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:yes /update

REM Enable Windows Update
sc config "Windows Update" start= auto

REM Configure Windows Installer
sc config "Windows Installer" start= manual

REM Configure WMI
sc config "Windows Management Instrumentation" start= auto

REM Power management (optimize for cloud)
sc config "Power" start= auto
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

REM Configure Windows Firewall for Remote Desktop
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
netsh advfirewall set allprofiles state on

REM Configure network profile
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

REM Set network location to Work
powershell -Command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"

REM Disable IPv6 if not needed (optional)
REM netsh interface ipv6 set global randomizeidentifiers=disabled
REM netsh interface ipv6 set privacy state=disabled

REM Configure RDP settings
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f

REM Enable automatic login for first boot (will be disabled by Sysprep)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d Administrator /f

REM Configure Windows Error Reporting
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f

REM Configure Automatic Updates
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 4 /f

echo Service configuration completed.
echo.
echo Configured services:
echo - Essential services: Enabled and set to automatic
echo - Unnecessary services: Disabled or set to manual
echo - Remote Desktop: Enabled with firewall rules
echo - Windows Update: Enabled for automatic updates
echo - Network services: Optimized for cloud deployment
echo.
echo Please reboot the system for all changes to take effect.
pause
