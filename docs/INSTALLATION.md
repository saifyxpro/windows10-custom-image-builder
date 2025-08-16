# 📖 Installation Guide

This comprehensive guide will walk you through setting up and using the Windows 10 Custom Image Builder.

## 🎯 Overview

The Windows 10 Custom Image Builder creates optimized virtual machine images using QEMU with VirtIO drivers, perfect for cloud deployment without requiring Hyper-V.

## ⚙️ System Requirements

### Minimum Requirements
- **Operating System**: Windows 10 (1903+) or Windows 11
- **RAM**: 16GB (8GB for VM + 8GB for host)
- **Storage**: 200GB free space
- **CPU**: 4 cores (2 for VM + 2 for host)
- **Privileges**: Administrator access

### Recommended Requirements
- **Operating System**: Windows 11 Pro/Enterprise
- **RAM**: 32GB+ (16GB for VM + 16GB for host)
- **Storage**: 500GB+ SSD storage
- **CPU**: 8+ cores (4 for VM + 4 for host)
- **Network**: High-speed internet connection

## 🚀 Quick Installation

### Option 1: Automated Setup (Recommended)

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/your-username/windows10-custom-image-builder.git
   cd windows10-custom-image-builder
   ```

2. **Run setup script as Administrator:**
   ```powershell
   .\scripts\Setup-Environment.ps1
   ```

3. **Download prerequisites:**
   ```powershell
   .\scripts\Download-Prerequisites.ps1
   ```

4. **Start building:**
   ```powershell
   .\scripts\Build-CustomImage.ps1
   ```

### Option 2: Manual Setup

If you prefer manual control over the installation process:

#### Step 1: Install QEMU

1. **Download QEMU for Windows:**
   - Visit: https://qemu.weilnetz.de/w64/
   - Download latest stable version (e.g., `qemu-w64-setup-20231009.exe`)

2. **Install QEMU:**
   ```powershell
   # Run installer as Administrator
   Start-Process -FilePath "qemu-w64-setup-20231009.exe" -ArgumentList "/S" -Wait
   
   # Add to PATH (if not done automatically)
   $env:Path += ";C:\Program Files\qemu"
   [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
   ```

#### Step 2: Download Required Files

1. **Windows 10 ISO:**
   - **Option A**: Microsoft Media Creation Tool
     - Visit: https://www.microsoft.com/software-download/windows10
     - Download and run Media Creation Tool
     - Select "Create installation media"
     - Choose ISO file format
   
   - **Option B**: Windows 10 Enterprise Evaluation
     - Visit: https://www.microsoft.com/evalcenter/evaluate-windows-10-enterprise
     - Download 90-day evaluation version

2. **VirtIO Drivers:**
   ```powershell
   # Download latest VirtIO drivers
   $virtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
   Invoke-WebRequest -Uri $virtioUrl -OutFile "iso\virtio-win.iso"
   ```

#### Step 3: Prepare Directory Structure

```powershell
# Create required directories
New-Item -ItemType Directory -Force -Path @(
    "iso",
    "drivers", 
    "output",
    "temp",
    "logs",
    "config"
)

# Move ISOs to iso directory
Move-Item "windows10.iso" "iso\"
# virtio-win.iso should already be in iso\ from Step 2
```

## 🔧 Configuration

### Build Configuration

Edit `config\build-config.json` to customize your build:

```json
{
  "vm": {
    "memory": "8192",        // VM RAM in MB
    "cpus": "4",             // Number of CPU cores
    "diskSize": "150G",      // Virtual disk size
    "diskFormat": "qcow2"    // Disk format (qcow2, raw, vhd)
  },
  "windows": {
    "edition": "Pro",        // Windows edition
    "language": "en-US",     // Installation language
    "updates": true          // Install Windows updates
  }
}
```

### Advanced Configuration Options

#### Memory Settings
- **Minimum**: 4GB (4096 MB) - Basic functionality
- **Recommended**: 8GB (8192 MB) - Optimal performance
- **High-Performance**: 16GB (16384 MB) - For heavy workloads

#### CPU Settings
- **Minimum**: 2 cores - Basic installation
- **Recommended**: 4 cores - Balanced performance
- **High-Performance**: 8 cores - Maximum speed

#### Disk Settings
- **Minimum**: 80GB - Windows 10 + drivers
- **Recommended**: 150GB - Windows + updates + applications
- **Extended**: 200GB+ - Additional software and data

### Network Configuration

The builder supports various network configurations:

```json
{
  "network": {
    "type": "user",           // NAT networking (default)
    "hostfwd": [
      "tcp::3389-:3389"      // RDP forwarding
    ]
  }
}
```

## 🏗️ Build Process

### Phase 1: Environment Setup (5-10 minutes)
- QEMU installation and configuration
- Directory structure creation
- Prerequisite validation

### Phase 2: Download Prerequisites (15-60 minutes)
- Windows 10 ISO download/verification
- VirtIO drivers download
- File integrity checks

### Phase 3: VM Creation (2-5 minutes)
- Virtual disk creation
- VM configuration
- Boot preparation

### Phase 4: Windows Installation (45-60 minutes)
- Automated Windows installation
- VirtIO driver integration
- Initial system configuration

### Phase 5: System Configuration (30-45 minutes)
- Windows updates installation
- Service optimization
- Security configuration
- Remote Desktop enablement

### Phase 6: Sysprep & Generalization (10-15 minutes)
- System generalization
- Unique identifier removal
- OOBE preparation

### Phase 7: Image Conversion (15-30 minutes)
- Format conversion (RAW, VHD, etc.)
- Compression (optional)
- Cloud-ready optimization

## 🐛 Troubleshooting Installation

### Common Issues

#### QEMU Installation Fails
```powershell
# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run PowerShell as Administrator"
}

# Manual QEMU installation
Invoke-WebRequest -Uri "https://qemu.weilnetz.de/w64/qemu-w64-setup-20231009.exe" -OutFile "$env:TEMP\qemu-setup.exe"
Start-Process -FilePath "$env:TEMP\qemu-setup.exe" -ArgumentList "/S" -Wait
```

#### Insufficient Disk Space
```powershell
# Check available space
Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq "C:" | Select-Object @{Name="FreeSpaceGB";Expression={[math]::Round($_.FreeSpace/1GB,2)}}

# Clean up system (run as Administrator)
cleanmgr /sagerun:1
```

#### Download Issues
```powershell
# Test internet connectivity
Test-NetConnection -ComputerName "8.8.8.8" -Port 53

# Alternative VirtIO download
$virtioUrl = "https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md"
# Check GitHub releases page for alternative download links
```

#### PowerShell Execution Policy
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current session (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Or set for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Performance Optimization

#### For Systems with Limited Resources
```json
{
  "vm": {
    "memory": "4096",        // Reduce to 4GB if needed
    "cpus": "2",             // Reduce to 2 cores if needed
    "diskSize": "80G"        // Minimum disk size
  },
  "performance": {
    "services": {
      "disable": [
        "Windows Search",
        "Superfetch",
        "Themes",
        "Windows Update"       // Disable during build, enable later
      ]
    }
  }
}
```

#### For High-Performance Systems
```json
{
  "vm": {
    "memory": "16384",       // Use more RAM if available
    "cpus": "8",             // Use more cores if available
    "diskSize": "200G"       // Larger disk for applications
  },
  "output": {
    "compress": false        // Skip compression for faster builds
  }
}
```

## 🔐 Security Considerations

### Default Credentials
The build process creates these accounts:
- **Administrator**: Password encoded in unattend.xml (change after deployment)
- **clouduser**: Default user account (change after deployment)

### Security Hardening
```powershell
# After deployment, run these commands:

# Change Administrator password
net user Administrator "NewSecurePassword123!"

# Change clouduser password  
net user clouduser "NewUserPassword123!"

# Enable Windows Firewall
netsh advfirewall set allprofiles state on

# Configure automatic updates
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 4
```

### Network Security
- Default configuration includes basic firewall rules
- RDP is enabled but should be secured with certificates
- Consider VPN access for production deployments

## 📊 Resource Usage During Build

| Phase | CPU Usage | RAM Usage | Disk I/O | Duration |
|-------|-----------|-----------|----------|----------|
| Setup | Low | Low | Low | 5-10 min |
| Downloads | Low | Low | Medium | 15-60 min |
| Installation | High | High | High | 45-60 min |
| Configuration | Medium | High | Medium | 30-45 min |
| Sysprep | Low | Medium | Medium | 10-15 min |
| Conversion | Medium | Low | High | 15-30 min |

## 🌐 Cloud Deployment Preparation

After building your image, it will be optimized for:

- **DigitalOcean**: RAW format with VirtIO drivers
- **AWS EC2**: VHD format with enhanced networking
- **Azure**: VHD format with Azure agents
- **Google Cloud Platform**: RAW format with GCP tools
- **Vultr**: RAW/ISO format support
- **Linode**: RAW format compatibility

## 📝 Next Steps

After successful installation:

1. **Verify Build**: Test your image in QEMU
2. **Upload to Cloud**: Follow cloud-specific deployment guides
3. **Security Review**: Implement additional security measures
4. **Monitoring Setup**: Configure monitoring and alerts
5. **Backup Strategy**: Plan image versioning and backups

## 🔄 Updates and Maintenance

### Updating QEMU
```powershell
# Check current version
qemu-system-x86_64.exe --version

# Download and install newer version
.\scripts\Setup-Environment.ps1 -Force
```

### Updating VirtIO Drivers
```powershell
# Download latest drivers
.\scripts\Download-Prerequisites.ps1 -Force
```

### Updating Build Scripts
```powershell
# Pull latest changes from repository
git pull origin main

# Review changes
git diff HEAD~1
```

## 💡 Tips for Success

1. **Start Small**: Begin with minimum configuration and scale up
2. **Monitor Resources**: Watch system performance during build
3. **Regular Backups**: Back up working configurations
4. **Test Deployments**: Always test images before production use
5. **Documentation**: Document any custom modifications
6. **Community**: Join discussions and share experiences

## 📞 Getting Help

If you encounter issues during installation:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review log files in the `logs/` directory
3. Search existing GitHub issues
4. Create a new issue with detailed information
5. Join community discussions

Remember to include:
- System specifications
- Error messages
- Log file contents
- Steps to reproduce the issue

---

**Next**: Once installation is complete, see [CLOUD-DEPLOYMENT.md](CLOUD-DEPLOYMENT.md) for deploying your custom image to various cloud providers.
