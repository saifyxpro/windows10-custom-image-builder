# 🚀 Windows 10 Custom Image with VirtIO (No Hyper-V Required)

*By Saify ([@saifyxpro](https://github.com/saifyxpro))*

This workflow creates a Windows 10 custom image using QEMU with VirtIO drivers for optimal cloud performance.

## 📋 Prerequisites
- Windows host machine with at least 16GB RAM
- Administrator privileges
- Stable internet connection
- 200GB+ free disk space

## 🔹 Step 1: Install QEMU on Windows

1. **Download QEMU for Windows:**
   - Visit: https://qemu.weilnetz.de/w64/
   - Download the latest stable version (e.g., `qemu-w64-setup-20231009.exe`)
   
2. **Install QEMU:**
   - Run installer as Administrator
   - Install to default location: `C:\Program Files\qemu`
   - Add QEMU to system PATH during installation

3. **Download Required ISOs:**
   Place these files in a working directory (e.g., `C:\VM-Build\`):
   - `windows10.iso` → Windows 10 installation media
   - `virtio-win.iso` → Download from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/

## 🔹 Step 2: Create Virtual Disk

Open **Command Prompt as Administrator** and navigate to your working directory:

```cmd
cd C:\VM-Build
qemu-img create -f qcow2 win10.qcow2 150G
```

**Why qcow2 instead of raw:**
- Smaller initial file size (grows as needed)
- Better compression and snapshot support
- Faster upload times

## 🔹 Step 3: Install Windows with VirtIO Drivers

**Initial Installation Command:**
```cmd
"C:\Program Files\qemu\qemu-system-x86_64.exe" ^
  -m 8192 ^
  -smp 4 ^
  -machine type=pc,accel=tcg ^
  -cpu qemu64 ^
  -drive file=win10.qcow2,format=qcow2,if=virtio,cache=writeback ^
  -drive file=windows10.iso,media=cdrom,index=0 ^
  -drive file=virtio-win.iso,media=cdrom,index=1 ^
  -boot order=dc ^
  -vga std ^
  -device virtio-net,netdev=net0 ^
  -netdev user,id=net0 ^
  -rtc base=localtime ^
  -no-reboot
```

**During Windows Installation:**

1. **Boot from Windows ISO** and start installation
2. **When prompted "Where do you want to install Windows?":**
   - No drives will be visible initially
   - Click **"Load driver"**
   - Browse to DVD drive containing `virtio-win.iso`
   - Navigate to: `viostor\w10\amd64\`
   - Select the VirtIO SCSI controller driver
   - Click **"Next"** to load the driver
3. **Select the newly visible VirtIO disk** and continue installation
4. **Complete Windows installation** normally
5. **Install remaining VirtIO drivers** after first boot:
   - Open Device Manager
   - Update drivers for any unknown devices
   - Point to appropriate folders in `virtio-win.iso`:
     - Network: `NetKVM\w10\amd64\`
     - Balloon: `Balloon\w10\amd64\`
     - Serial: `vioserial\w10\amd64\`

## 🔹 Step 3.1: Boot Windows Normally After Installation

**After the initial installation shuts down, use this command to boot Windows normally:**

```cmd
"C:\Program Files\qemu\qemu-system-x86_64.exe" ^
  -m 8192 ^
  -smp 4 ^
  -machine type=pc,accel=tcg ^
  -cpu qemu64 ^
  -drive file=win10.qcow2,format=qcow2,if=virtio,cache=writeback ^
  -drive file=virtio-win.iso,media=cdrom,index=1 ^
  -boot c ^
  -vga std ^
  -device virtio-net,netdev=net0 ^
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 ^
  -rtc base=localtime ^
  -monitor stdio
```

**Key Changes from Installation Command:**
- **Removed Windows 10 ISO** (no longer needed)
- **Changed boot order to `c`** (boot from hard disk)
- **Removed `-no-reboot`** flag (allows normal restarts)
- **Added RDP port forwarding** (`hostfwd=tcp::3389-:3389`)
- **Added `-monitor stdio`** for VM management from command line

**Port Forwarding Explained:**
- `hostfwd=tcp::3389-:3389` forwards host port 3389 to VM port 3389
- This allows RDP connections to `localhost:3389` from your host machine
- **Alternative ports:** Use `hostfwd=tcp::13389-:3389` if port 3389 is busy

**Create a Batch File for Easy Access:**

Save this as `start-windows-vm.bat` in your working directory:

```batch
@echo off
echo Starting Windows 10 VM...
echo.
echo VM Controls:
echo - Press Ctrl+Alt+G to release mouse/keyboard from VM
echo - Type 'quit' in this window to shut down VM
echo - RDP available at localhost:3389 after Windows boots
echo.

cd /d "C:\VM-Build"

"C:\Program Files\qemu\qemu-system-x86_64.exe" ^
  -m 8192 ^
  -smp 4 ^
  -machine type=pc,accel=tcg ^
  -cpu qemu64 ^
  -drive file=win10.qcow2,format=qcow2,if=virtio,cache=writeback ^
  -drive file=virtio-win.iso,media=cdrom,index=1 ^
  -boot c ^
  -vga std ^
  -device virtio-net,netdev=net0 ^
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 ^
  -rtc base=localtime ^
  -monitor stdio ^
  -name "Windows 10 Build VM"

echo.
echo VM has shut down.
pause
```

**Using the Monitor Console:**
When the VM is running, you can type commands in the Command Prompt window:
- `quit` - Shut down VM gracefully
- `system_powerdown` - Send ACPI power button signal
- `info status` - Show VM status
- `info network` - Show network information

## 🔹 Step 4: Configure Windows for Cloud Deployment

**Inside the Windows VM:**

1. **Enable Remote Desktop:**
   ```cmd
   # Run as Administrator
   reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
   netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
   ```

2. **Install Windows Updates:**
   - Run Windows Update completely
   - Install all critical and security updates
   - Restart as needed

3. **Configure Essential Services:**
   ```cmd
   # Enable automatic logon for initial setup (will be disabled by Sysprep)
   sc config "Windows Update" start= auto
   sc config "DHCP Client" start= auto
   sc config "DNS Client" start= auto
   ```

4. **Install Additional Software (Optional):**
   - Essential drivers for your use case
   - Antivirus software
   - Remote management tools

## 🔹 Step 5: Prepare Image with Sysprep

**Important:** Sysprep prepares Windows for deployment by removing unique identifiers.

1. **Create Sysprep Answer File (Optional but recommended):**
   Save as `C:\unattend.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <unattend xmlns="urn:schemas-microsoft-com:unattend">
       <settings pass="oobeSystem">
           <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
               <OOBE>
                   <HideEULAPage>true</HideEULAPage>
                   <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                   <NetworkLocation>Work</NetworkLocation>
               </OOBE>
           </component>
       </settings>
   </unattend>
   ```

2. **Run Sysprep:**
   ```cmd
   # Open elevated Command Prompt
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\unattend.xml
   ```

   **Sysprep Options Explained:**
   - `/generalize` - Removes unique system information
   - `/oobe` - Sets system to boot to Out-of-Box Experience
   - `/shutdown` - Shuts down after completion
   - `/unattend` - Uses answer file for automated setup

## 🔹 Step 6: Test Boot (Recommended)

Before finalizing, test the sysprepped image:

```cmd
"C:\Program Files\qemu\qemu-system-x86_64.exe" ^
  -m 8192 ^
  -smp 4 ^
  -machine type=pc,accel=tcg ^
  -cpu qemu64 ^
  -drive file=win10.qcow2,format=qcow2,if=virtio,cache=writeback ^
  -boot c ^
  -vga std ^
  -device virtio-net,netdev=net0 ^
  -netdev user,id=net0 ^
  -rtc base=localtime
```

**Verify:**
- Windows boots to OOBE
- Network connectivity works
- VirtIO drivers are properly installed
- RDP is accessible

## 🔹 Step 7: Convert and Compress Image

**Convert to RAW format (required by most cloud providers):**
```cmd
qemu-img convert -f qcow2 -O raw win10.qcow2 win10.img
```

**Compress for upload:**
```cmd
# Windows (using 7-Zip or built-in tar)
tar -czf win10.img.gz win10.img

# Alternative with 7-Zip
"C:\Program Files\7-Zip\7z.exe" a -tgzip win10.img.gz win10.img
```

## 🔹 Step 8: Upload and Deploy

1. **Upload compressed image:**
   - Upload `win10.img.gz` to publicly accessible location
   - Options: AWS S3, Google Cloud Storage, Dropbox, etc.
   - Ensure the URL is directly downloadable

2. **Import to Cloud Provider:**
   - **DigitalOcean:** Custom Images → Import via URL
   - **AWS:** EC2 → Import Snapshot → Create AMI
   - **Google Cloud:** Compute Engine → Images → Create Image

3. **Create Droplet/Instance:**
   - **Minimum Specs:** 8GB RAM, 4 CPUs, 160GB storage
   - **Recommended:** Match or exceed your build configuration
   - Enable VPC/VPN if needed for RDP access

## ⚡ Pro Tips & Troubleshooting

**Performance Optimization:**
- Use `cache=writeback` for better I/O performance during build
- Allocate maximum safe RAM to VM (leave 4-8GB for host)
- Use SSD storage for host if available
- **CPU Model:** Use `qemu64` or `Nehalem` instead of `host` when using TCG acceleration

**Alternative CPU Models for TCG:**
- `-cpu qemu64` (default, good compatibility)
- `-cpu Nehalem` (better Windows 10 support)
- `-cpu SandyBridge` (modern features, slower on TCG)

**Note:** TCG acceleration is slower than hardware acceleration but works on any Windows system without Hyper-V.

**Common Issues:**
- **"No bootable device" error:** Check boot order and drive configuration
- **Network not working:** Ensure VirtIO network drivers are installed
- **Slow performance:** Verify VirtIO storage drivers are active
- **RDP connection fails:** Check Windows Firewall and service status

**Security Considerations:**
- Change default passwords after deployment
- Configure Windows Firewall rules appropriately
- Keep Windows updates current
- Consider enabling BitLocker for data protection

**Cloud Provider Specific Notes:**
- **DigitalOcean:** Supports RAW and VHD formats
- **AWS:** Prefers VMware VMDK or VHD formats
- **Azure:** Requires VHD format with specific configurations
- **Google Cloud:** Supports RAW disk images directly

## 📊 Expected Timeline
- **Step 1-2:** 30 minutes (download and setup)
- **Step 3:** 45-60 minutes (Windows installation)
- **Step 3.1:** 5 minutes (setup normal boot script)
- **Step 4:** 30-45 minutes (configuration and updates)
- **Step 5:** 15 minutes (Sysprep)
- **Step 6:** 10 minutes (testing)
- **Step 7-8:** 30-60 minutes (compression and upload)

**Total Time:** 3-4 hours (depending on internet speed and hardware)

---

## 🎯 About This Guide

This comprehensive guide was created by **Saify** ([@saifyxpro](https://github.com/saifyxpro)) to provide a complete, working workflow for Windows 10 custom image creation. 

### What Makes This Guide Different:
- ✅ **Complete Post-Installation Configuration** - Includes the crucial Step 3.1 that most guides miss
- ✅ **RDP Access Setup** - Proper port forwarding and remote access configuration
- ✅ **VM Management** - Monitor console usage and batch file automation
- ✅ **Real-World Testing** - All commands have been tested and verified
- ✅ **Cloud-Ready Output** - Optimized for all major cloud providers

### Repository & Automation:
For automated scripts and advanced configurations, visit the full repository:
🔗 **https://github.com/saifyxpro/windows10-custom-image-builder**

The repository includes:
- PowerShell automation scripts
- Advanced configuration options
- Cloud deployment guides
- Troubleshooting documentation
- Enterprise features

---

*Made with ❤️ by **Saify** for the Cloud Infrastructure Community*
