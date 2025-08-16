# 🔧 Troubleshooting Guide

This guide covers common issues and their solutions when building Windows 10 custom images.

## 🚨 Quick Diagnosis

### System Health Check
```powershell
# Run this script to check your system
function Test-SystemHealth {
    Write-Host "System Health Check" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    
    # PowerShell version
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    
    # Administrator check
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Host "Administrator Rights: $isAdmin" -ForegroundColor $(if($isAdmin){"Green"}else{"Red"})
    
    # Disk space
    $drive = (Get-Location).Drive
    $freeSpace = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq $drive.Name).FreeSpace / 1GB, 2)
    Write-Host "Available Disk Space: $freeSpace GB" -ForegroundColor $(if($freeSpace -gt 200){"Green"}elseif($freeSpace -gt 100){"Yellow"}else{"Red"})
    
    # RAM
    $totalRAM = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Write-Host "Total RAM: $totalRAM GB" -ForegroundColor $(if($totalRAM -gt 16){"Green"}elseif($totalRAM -gt 8){"Yellow"}else{"Red"})
    
    # QEMU check
    $qemuPath = Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue
    Write-Host "QEMU Available: $($qemuPath -ne $null)" -ForegroundColor $(if($qemuPath){"Green"}else{"Red"})
    if ($qemuPath) { Write-Host "QEMU Path: $($qemuPath.Source)" -ForegroundColor Gray }
}

Test-SystemHealth
```

## 🏗️ Build Process Issues

### Issue: QEMU Installation Failed

**Symptoms:**
- Setup-Environment.ps1 fails during QEMU installation
- "Access denied" or permission errors
- Installation hangs indefinitely

**Solutions:**

1. **Check Administrator Rights:**
   ```powershell
   # Verify admin rights
   if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
       Write-Error "Please run PowerShell as Administrator"
       exit 1
   }
   ```

2. **Manual QEMU Installation:**
   ```powershell
   # Download manually
   $qemuUrl = "https://qemu.weilnetz.de/w64/qemu-w64-setup-20231009.exe"
   $installer = "$env:TEMP\qemu-installer.exe"
   Invoke-WebRequest -Uri $qemuUrl -OutFile $installer
   
   # Install silently
   Start-Process -FilePath $installer -ArgumentList "/S", "/D=C:\Program Files\qemu" -Wait -Verb RunAs
   
   # Add to PATH
   $env:Path += ";C:\Program Files\qemu"
   [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
   ```

3. **Alternative Installation Method:**
   ```powershell
   # Using Chocolatey (if available)
   if (Get-Command choco -ErrorAction SilentlyContinue) {
       choco install qemu -y
   }
   
   # Or using Windows Package Manager
   if (Get-Command winget -ErrorAction SilentlyContinue) {
       winget install QEMU.QEMU
   }
   ```

### Issue: Download Prerequisites Failed

**Symptoms:**
- VirtIO ISO download fails
- Network connectivity issues
- Corrupted downloads

**Solutions:**

1. **Check Network Connectivity:**
   ```powershell
   # Test internet connection
   Test-NetConnection -ComputerName "8.8.8.8" -Port 53
   Test-NetConnection -ComputerName "fedorapeople.org" -Port 443
   
   # Test with different DNS
   nslookup fedorapeople.org 8.8.8.8
   ```

2. **Manual VirtIO Download:**
   ```powershell
   # Alternative download sources
   $virtioUrls = @(
       "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso",
       "https://github.com/virtio-win/virtio-win-pkg-scripts/releases/latest/download/virtio-win.iso"
   )
   
   foreach ($url in $virtioUrls) {
       try {
           Write-Host "Trying: $url"
           Invoke-WebRequest -Uri $url -OutFile "iso\virtio-win.iso" -UseBasicParsing
           break
       } catch {
           Write-Warning "Failed: $($_.Exception.Message)"
       }
   }
   ```

3. **Proxy Configuration:**
   ```powershell
   # If behind corporate proxy
   $proxy = "http://proxy.company.com:8080"
   [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxy, $true)
   [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
   ```

### Issue: Virtual Disk Creation Failed

**Symptoms:**
- qemu-img fails to create disk
- "Permission denied" errors
- Insufficient disk space errors

**Solutions:**

1. **Check Disk Space:**
   ```powershell
   # Check available space
   Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq "C:" | 
   Select-Object @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
   
   # Clean up if needed
   cleanmgr /sagerun:1
   
   # Remove temporary files
   Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
   ```

2. **Alternative Disk Location:**
   ```powershell
   # Use different drive if needed
   $altPath = "D:\VM-Build\output\win10.qcow2"
   qemu-img create -f qcow2 $altPath 150G
   ```

3. **Fix Permissions:**
   ```powershell
   # Fix directory permissions
   $outputDir = "output"
   if (Test-Path $outputDir) {
       icacls $outputDir /grant "${env:USERNAME}:(OI)(CI)F" /T
   }
   ```

## 🖥️ Virtual Machine Issues

### Issue: VM Won't Boot from Windows ISO

**Symptoms:**
- VM starts but shows black screen
- "No bootable device" error
- Boot order issues

**Solutions:**

1. **Verify ISO Files:**
   ```powershell
   # Check ISO file integrity
   function Test-ISOIntegrity {
       param($ISOPath)
       
       if (-not (Test-Path $ISOPath)) {
           return $false
       }
       
       $fileSize = (Get-Item $ISOPath).Length / 1MB
       Write-Host "$ISOPath size: $([math]::Round($fileSize, 2)) MB"
       
       # Windows ISO should be 4-6GB, VirtIO should be ~200MB
       return $fileSize -gt 100
   }
   
   Test-ISOIntegrity "iso\windows10.iso"
   Test-ISOIntegrity "iso\virtio-win.iso"
   ```

2. **Fix Boot Order:**
   ```powershell
   # Ensure correct boot order parameters
   $bootArgs = @(
       "-boot", "order=dc",  # CD-ROM first, then disk
       "-drive", "file=iso\windows10.iso,media=cdrom,index=0",
       "-drive", "file=iso\virtio-win.iso,media=cdrom,index=1"
   )
   ```

3. **Alternative Boot Configuration:**
   ```powershell
   # Try different boot settings
   $altBootArgs = @(
       "-boot", "menu=on,strict=off",
       "-drive", "file=iso\windows10.iso,media=cdrom,readonly=on",
       "-drive", "file=iso\virtio-win.iso,media=cdrom,readonly=on"
   )
   ```

### Issue: VirtIO Drivers Not Found During Installation

**Symptoms:**
- No disk visible during Windows installation
- "Load driver" option doesn't find drivers
- Installation cannot proceed

**Solutions:**

1. **Verify VirtIO ISO Mount:**
   ```powershell
   # Check if VirtIO ISO is properly mounted
   # During installation, browse to E:\ or F:\ drive
   # Look for folder structure: viostor\w10\amd64\
   ```

2. **Manual Driver Path:**
   - During Windows installation, click "Load driver"
   - Browse to the VirtIO ISO (usually E: or F:)
   - Navigate to: `viostor\w10\amd64\`
   - Select the `.inf` file

3. **Alternative VirtIO Configuration:**
   ```powershell
   # Try different VirtIO interface
   $altStorageArgs = @(
       "-drive", "file=output\win10.qcow2,format=qcow2,if=virtio,cache=none,aio=native"
   )
   
   # Or fall back to IDE during installation
   $ideArgs = @(
       "-drive", "file=output\win10.qcow2,format=qcow2,if=ide"
   )
   ```

### Issue: VM Performance is Very Slow

**Symptoms:**
- VM takes very long to boot
- Installation process is extremely slow
- High CPU usage on host

**Solutions:**

1. **Optimize QEMU Parameters:**
   ```powershell
   # Enhanced performance settings
   $perfArgs = @(
       "-machine", "type=pc,accel=tcg,kernel_irqchip=off",
       "-cpu", "qemu64,+ssse3,+sse4.1,+sse4.2",
       "-smp", "4,cores=2,threads=2",
       "-m", "8192",
       "-drive", "file=output\win10.qcow2,format=qcow2,if=virtio,cache=writeback,aio=threads"
   )
   ```

2. **Host System Optimization:**
   ```powershell
   # Set high performance power plan
   powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
   
   # Disable Windows Defender real-time protection temporarily
   Set-MpPreference -DisableRealtimeMonitoring $true
   
   # Close unnecessary programs
   Get-Process | Where-Object {$_.ProcessName -like "*chrome*" -or $_.ProcessName -like "*firefox*"} | Stop-Process -Force
   ```

3. **Reduce VM Resource Usage:**
   ```json
   {
     "vm": {
       "memory": "6144",    // Reduce from 8192
       "cpus": "2",         // Reduce from 4
       "diskSize": "100G"   // Reduce from 150G
     }
   }
   ```

## 🔧 Windows Configuration Issues

### Issue: Windows Updates Fail

**Symptoms:**
- Windows Update gets stuck
- Error codes during update process
- Updates download but fail to install

**Solutions:**

1. **Reset Windows Update Components:**
   ```cmd
   # Run inside VM
   net stop wuauserv
   net stop cryptSvc
   net stop bits
   net stop msiserver
   
   ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
   ren C:\Windows\System32\catroot2 catroot2.old
   
   net start wuauserv
   net start cryptSvc
   net start bits
   net start msiserver
   ```

2. **Manual Update Download:**
   ```powershell
   # Download Windows Update Standalone Installer
   $updateUrl = "https://download.microsoft.com/download/..."
   # Use Microsoft Update Catalog for specific updates
   ```

3. **Disable Problematic Updates:**
   ```cmd
   # Hide specific updates if they cause issues
   wusa /uninstall /kb:XXXXXXX /quiet /norestart
   ```

### Issue: Remote Desktop Won't Enable

**Symptoms:**
- RDP checkbox is grayed out
- Cannot connect via RDP after enabling
- Firewall blocks connections

**Solutions:**

1. **Enable RDP via Registry:**
   ```cmd
   # Run as Administrator in VM
   reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
   
   # Enable RDP through firewall
   netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
   ```

2. **Configure RDP Service:**
   ```cmd
   # Enable Terminal Services
   sc config TermService start= auto
   sc start TermService
   
   # Configure RDP settings
   reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f
   ```

3. **Test RDP Connection:**
   ```powershell
   # From host machine
   mstsc /v:localhost:3389
   
   # Or test port
   Test-NetConnection -ComputerName localhost -Port 3389
   ```

### Issue: Sysprep Fails

**Symptoms:**
- Sysprep exits with error
- "Sysprep was not able to validate your Windows installation" 
- System fails to generalize

**Solutions:**

1. **Check Sysprep Logs:**
   ```cmd
   # View Sysprep logs
   type C:\Windows\System32\Sysprep\Panther\setuperr.log
   type C:\Windows\System32\Sysprep\Panther\setupact.log
   ```

2. **Common Sysprep Fixes:**
   ```cmd
   # Remove Windows Store apps that prevent Sysprep
   Get-AppxPackage -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
   
   # Clear Windows Update history
   net stop wuauserv
   rmdir /s /q C:\Windows\SoftwareDistribution\Download
   net start wuauserv
   
   # Remove temporary profiles
   reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /v ProfileImagePath /f
   ```

3. **Alternative Sysprep Command:**
   ```cmd
   # Try different Sysprep options
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /mode:vm
   
   # Or without /generalize for testing
   C:\Windows\System32\Sysprep\sysprep.exe /oobe /shutdown
   ```

## 📁 File and Permission Issues

### Issue: Cannot Access Output Files

**Symptoms:**
- "Access denied" when trying to access built images
- Files appear corrupted or incomplete
- Cannot copy or move image files

**Solutions:**

1. **Fix File Permissions:**
   ```powershell
   # Take ownership of output directory
   takeown /f output /r /d y
   icacls output /grant "${env:USERNAME}:(OI)(CI)F" /T
   
   # Or use specific file
   takeown /f "output\win10.qcow2"
   icacls "output\win10.qcow2" /grant "${env:USERNAME}:F"
   ```

2. **Check File Locks:**
   ```powershell
   # Find processes using the file
   Get-Process | Where-Object {$_.ProcessName -like "*qemu*"} | Stop-Process -Force
   
   # Use handle.exe (SysInternals) to find file locks
   # handle.exe output\win10.qcow2
   ```

3. **Safe File Operations:**
   ```powershell
   # Stop QEMU before file operations
   Get-Process -Name "*qemu*" -ErrorAction SilentlyContinue | Stop-Process -Force
   Start-Sleep 5
   
   # Then perform file operations
   Copy-Item "output\win10.qcow2" "backup\win10-backup.qcow2"
   ```

## 🔄 Image Conversion Issues

### Issue: Image Conversion Fails

**Symptoms:**
- qemu-img convert command fails
- Output files are corrupted
- Conversion takes extremely long time

**Solutions:**

1. **Check Source Image:**
   ```powershell
   # Verify source image integrity
   qemu-img check output\win10.qcow2
   
   # Get image information
   qemu-img info output\win10.qcow2
   ```

2. **Try Different Conversion Options:**
   ```powershell
   # Basic conversion
   qemu-img convert -f qcow2 -O raw output\win10.qcow2 output\win10.img
   
   # With progress indicator
   qemu-img convert -p -f qcow2 -O raw output\win10.qcow2 output\win10.img
   
   # Compressed conversion
   qemu-img convert -f qcow2 -O raw -c output\win10.qcow2 output\win10.img
   ```

3. **Alternative Tools:**
   ```powershell
   # Using VBoxManage (if VirtualBox is installed)
   VBoxManage clonehd output\win10.qcow2 output\win10.vdi --format VDI
   VBoxManage clonehd output\win10.vdi output\win10.img --format RAW
   ```

## 🌐 Network and Connectivity Issues

### Issue: No Network in VM

**Symptoms:**
- VM has no internet connectivity
- Cannot download Windows updates
- Network adapter not detected

**Solutions:**

1. **Check Network Configuration:**
   ```powershell
   # Verify network arguments
   $netArgs = @(
       "-device", "virtio-net,netdev=net0",
       "-netdev", "user,id=net0,hostfwd=tcp::3389-:3389"
   )
   ```

2. **Install Network Drivers:**
   - In VM, open Device Manager
   - Look for unknown network devices
   - Browse to VirtIO ISO: `NetKVM\w10\amd64\`
   - Install the network driver

3. **Alternative Network Configuration:**
   ```powershell
   # Use e1000 instead of VirtIO if issues persist
   $altNetArgs = @(
       "-device", "e1000,netdev=net0",
       "-netdev", "user,id=net0"
   )
   ```

## 📊 Performance Monitoring and Optimization

### Monitor Build Progress

```powershell
# Create a monitoring script
function Monitor-BuildProgress {
    param($VMName = "win10-custom")
    
    while ($true) {
        Clear-Host
        Write-Host "Build Progress Monitor" -ForegroundColor Green
        Write-Host "=====================" -ForegroundColor Green
        
        # Check QEMU processes
        $qemuProcs = Get-Process -Name "*qemu*" -ErrorAction SilentlyContinue
        Write-Host "QEMU Processes: $($qemuProcs.Count)" -ForegroundColor Cyan
        
        # Check disk usage
        if (Test-Path "output\$VMName.qcow2") {
            $diskSize = [math]::Round((Get-Item "output\$VMName.qcow2").Length / 1GB, 2)
            Write-Host "Disk Size: $diskSize GB" -ForegroundColor Yellow
        }
        
        # Check CPU and Memory usage
        $cpu = (Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $mem = (Get-WmiObject -Class Win32_OperatingSystem)
        $memUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB, 2)
        
        Write-Host "CPU Usage: $cpu%" -ForegroundColor $(if($cpu -gt 80){"Red"}elseif($cpu -gt 50){"Yellow"}else{"Green"})
        Write-Host "Memory Used: $memUsed GB" -ForegroundColor Cyan
        
        Start-Sleep 30
    }
}

# Run monitoring
# Monitor-BuildProgress
```

### Emergency Stop Procedures

```powershell
# Emergency stop all QEMU processes
function Stop-AllQEMU {
    Write-Host "Stopping all QEMU processes..." -ForegroundColor Red
    Get-Process -Name "*qemu*" -ErrorAction SilentlyContinue | Stop-Process -Force
    
    # Wait for processes to stop
    Start-Sleep 5
    
    # Verify all stopped
    $remaining = Get-Process -Name "*qemu*" -ErrorAction SilentlyContinue
    if ($remaining) {
        Write-Host "Some processes are still running:" -ForegroundColor Yellow
        $remaining | Format-Table ProcessName, Id, CPU
    } else {
        Write-Host "All QEMU processes stopped." -ForegroundColor Green
    }
}

# Clean up temporary files
function Clear-BuildTemp {
    Write-Host "Cleaning temporary files..." -ForegroundColor Yellow
    
    $tempPaths = @(
        "temp\*",
        "$env:TEMP\qemu*",
        "$env:TEMP\virtio*"
    )
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned: $path" -ForegroundColor Gray
        }
    }
}
```

## 📞 Getting Additional Help

### Log Collection for Support

```powershell
# Collect all relevant logs and system information
function Export-TroubleshootingInfo {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportPath = "troubleshooting-$timestamp"
    New-Item -ItemType Directory -Path $exportPath -Force
    
    # System information
    Get-ComputerInfo | Out-File "$exportPath\system-info.txt"
    Get-Process | Out-File "$exportPath\processes.txt"
    Get-Service | Out-File "$exportPath\services.txt"
    
    # QEMU information
    if (Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue) {
        qemu-system-x86_64.exe --version | Out-File "$exportPath\qemu-version.txt"
    }
    
    # Copy logs
    if (Test-Path "logs") {
        Copy-Item "logs\*" "$exportPath\" -Recurse -ErrorAction SilentlyContinue
    }
    
    # Configuration files
    if (Test-Path "config") {
        Copy-Item "config\*" "$exportPath\" -Recurse -ErrorAction SilentlyContinue
    }
    
    # Compress for sharing
    Compress-Archive -Path "$exportPath\*" -DestinationPath "$exportPath.zip"
    
    Write-Host "Troubleshooting information exported to: $exportPath.zip" -ForegroundColor Green
}
```

### Community Resources

- **GitHub Issues**: [Report bugs and search solutions](https://github.com/saifyxpro/windows10-custom-image-builder/issues)
- **Discussions**: [Ask questions and share tips](https://github.com/saifyxpro/windows10-custom-image-builder/discussions)
- **Wiki**: [Community-contributed solutions](https://github.com/saifyxpro/windows10-custom-image-builder/wiki)
- **Discord/Slack**: [Real-time community support](https://discord.gg/your-server)

### Professional Support

For enterprise deployments or complex issues:
- Email: support@saify.dev
- Professional consulting services available
- Custom solution development
- Training and workshops

---

Remember: Most issues can be resolved by carefully following the error messages and checking system requirements. When in doubt, start with a clean environment and minimal configuration.
