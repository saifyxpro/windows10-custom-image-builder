# ☁️ Cloud Deployment Guide

This guide covers deploying your custom Windows 10 image to major cloud providers.

## 🎯 Pre-Deployment Checklist

Before uploading your image to any cloud provider:

- ✅ **Image is Sysprepped**: Generalized and ready for deployment
- ✅ **VirtIO Drivers Installed**: For optimal performance
- ✅ **Remote Desktop Enabled**: For remote access
- ✅ **Windows Updates Applied**: Latest security patches
- ✅ **Correct Format**: Provider-specific format requirements
- ✅ **Size Optimized**: Within provider limits
- ✅ **Security Configured**: Firewalls and access controls

## 🌊 DigitalOcean

### Requirements
- **Format**: RAW or VHD
- **Maximum Size**: 100GB
- **Architecture**: x64
- **Boot**: BIOS (not UEFI)

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to RAW format
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "raw" -VMName "win10-custom"
   
   # Compress for upload
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.raw" -OutputFormat "raw" -VMName "win10-custom" -Compress
   ```

2. **Upload to Public URL:**
   ```powershell
   # Upload compressed image to a public URL (examples):
   # - AWS S3 with public read access
   # - Google Cloud Storage with public access
   # - Azure Blob Storage with public access
   # - Dropbox/Google Drive public link
   # - Your own web server
   
   # Example S3 upload:
   aws s3 cp output/win10-custom.raw.gz s3://your-bucket/win10-custom.raw.gz --acl public-read
   
   # Get public URL:
   # https://your-bucket.s3.amazonaws.com/win10-custom.raw.gz
   ```

3. **Import via DigitalOcean Control Panel:**
   - Go to Images → Custom Images
   - Click "Import via URL"
   - Enter image URL: `https://your-bucket.s3.amazonaws.com/win10-custom.raw.gz`
   - Select region for import
   - Add tags and description
   - Click "Import Image"

4. **Create Droplet:**
   ```bash
   # Via CLI (doctl)
   doctl compute image list --public false  # Find your image ID
   doctl compute droplet create win10-vm \
     --image your-image-id \
     --size s-4vcpu-8gb \
     --region nyc3 \
     --ssh-keys your-ssh-key-id
   ```

### DigitalOcean-Specific Optimizations

```json
{
  "cloud": {
    "digitalocean": {
      "features": {
        "monitoring": true,
        "ipv6": true,
        "private_networking": true
      },
      "optimizations": {
        "disable_ipv6": false,
        "enable_do_agent": true
      }
    }
  }
}
```

## 🟠 AWS EC2

### Requirements
- **Format**: VHD, VMDK, or RAW
- **Maximum Size**: 16TB
- **Architecture**: x64 or ARM64
- **Boot**: BIOS or UEFI

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to VHD format (preferred)
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "vhd" -VMName "win10-custom"
   ```

2. **Upload to S3:**
   ```bash
   # Create S3 bucket
   aws s3 mb s3://your-vm-images-bucket
   
   # Upload image
   aws s3 cp output/win10-custom.vhd s3://your-vm-images-bucket/win10-custom.vhd
   ```

3. **Create VM Import Role:**
   ```json
   # trust-policy.json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals":{
             "sts:Externalid": "vmimport"
           }
         }
       }
     ]
   }
   ```
   
   ```bash
   # Create role
   aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
   
   # Attach policy
   aws iam attach-role-policy --role-name vmimport --policy-arn arn:aws:iam::aws:policy/service-role/VMImportExportRoleForAWSConnector
   ```

4. **Import as AMI:**
   ```json
   # containers.json
   [
     {
       "Description": "Windows 10 Custom Image",
       "Format": "vhd", 
       "UserBucket": {
         "S3Bucket": "your-vm-images-bucket",
         "S3Key": "win10-custom.vhd"
       }
     }
   ]
   ```
   
   ```bash
   # Start import task
   aws ec2 import-image --description "Windows 10 Custom" --disk-containers file://containers.json
   
   # Check import progress
   aws ec2 describe-import-image-tasks --import-task-ids import-ami-1234567890abcdef0
   ```

5. **Launch EC2 Instance:**
   ```bash
   # Launch instance with your custom AMI
   aws ec2 run-instances \
     --image-id ami-1234567890abcdef0 \
     --count 1 \
     --instance-type m5.large \
     --key-name your-key-pair \
     --security-groups your-security-group
   ```

### AWS-Specific Optimizations

```json
{
  "cloud": {
    "aws": {
      "features": {
        "enhanced_networking": true,
        "sriov_net_support": true,
        "ena_support": true
      },
      "metadata": {
        "block_device_mappings": [
          {
            "device_name": "/dev/sda1",
            "ebs": {
              "volume_type": "gp3",
              "volume_size": 150,
              "delete_on_termination": true
            }
          }
        ]
      }
    }
  }
}
```

## 🔷 Microsoft Azure

### Requirements
- **Format**: VHD (fixed, not dynamic)
- **Maximum Size**: 1023GB
- **Architecture**: x64
- **Boot**: Generation 1 (BIOS)

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to fixed VHD format
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "vhd" -VMName "win10-custom"
   
   # Verify VHD is fixed format (not dynamic)
   qemu-img info output/win10-custom.vhd
   ```

2. **Upload to Azure Storage:**
   ```bash
   # Create storage account
   az storage account create \
     --name yourstorageaccount \
     --resource-group your-resource-group \
     --location eastus \
     --sku Standard_LRS
   
   # Get connection string
   az storage account show-connection-string \
     --name yourstorageaccount \
     --resource-group your-resource-group
   
   # Create container
   az storage container create \
     --name vhds \
     --connection-string "your-connection-string"
   
   # Upload VHD
   az storage blob upload \
     --file output/win10-custom.vhd \
     --name win10-custom.vhd \
     --container-name vhds \
     --type page \
     --connection-string "your-connection-string"
   ```

3. **Create Managed Disk:**
   ```bash
   # Get blob URL
   az storage blob url \
     --name win10-custom.vhd \
     --container-name vhds \
     --connection-string "your-connection-string"
   
   # Create managed disk from VHD
   az disk create \
     --resource-group your-resource-group \
     --name win10-custom-disk \
     --source https://yourstorageaccount.blob.core.windows.net/vhds/win10-custom.vhd \
     --os-type windows
   ```

4. **Create VM from Managed Disk:**
   ```bash
   az vm create \
     --resource-group your-resource-group \
     --name win10-custom-vm \
     --attach-os-disk win10-custom-disk \
     --os-type windows \
     --size Standard_D4s_v3
   ```

### Azure-Specific Optimizations

```powershell
# Install Azure VM Agent (during image preparation)
# Download from: https://github.com/Azure/WindowsVMAgent

# Registry optimizations for Azure
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
```

## 🟡 Google Cloud Platform (GCP)

### Requirements
- **Format**: RAW or VMDK
- **Maximum Size**: 10TB
- **Architecture**: x64
- **Boot**: BIOS or UEFI

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to RAW format
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "raw" -VMName "win10-custom"
   
   # Compress for faster upload
   gzip output/win10-custom.raw
   ```

2. **Upload to Cloud Storage:**
   ```bash
   # Create bucket
   gsutil mb gs://your-vm-images-bucket
   
   # Upload compressed image
   gsutil cp output/win10-custom.raw.gz gs://your-vm-images-bucket/
   ```

3. **Create Custom Image:**
   ```bash
   # Create image from Cloud Storage
   gcloud compute images create win10-custom \
     --source-uri=gs://your-vm-images-bucket/win10-custom.raw.gz \
     --os=windows-10 \
     --description="Custom Windows 10 image with VirtIO drivers"
   ```

4. **Create VM Instance:**
   ```bash
   gcloud compute instances create win10-custom-vm \
     --image=win10-custom \
     --machine-type=n1-standard-4 \
     --zone=us-central1-a \
     --boot-disk-size=150GB \
     --boot-disk-type=pd-ssd
   ```

### GCP-Specific Optimizations

```json
{
  "cloud": {
    "gcp": {
      "features": {
        "enable_ip_forwarding": false,
        "can_ip_forward": false,
        "automatic_restart": true,
        "on_host_maintenance": "MIGRATE"
      },
      "metadata": {
        "enable-oslogin": "FALSE",
        "windows-startup-script-url": "gs://your-bucket/startup-script.ps1"
      }
    }
  }
}
```

## 🟣 Vultr

### Requirements
- **Format**: RAW or ISO
- **Maximum Size**: No specified limit
- **Architecture**: x64

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to RAW format
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "raw" -VMName "win10-custom"
   ```

2. **Upload via Vultr API:**
   ```bash
   # Using curl to upload
   curl -X POST "https://api.vultr.com/v2/snapshots" \
     -H "Authorization: Bearer your-api-key" \
     -H "Content-Type: application/json" \
     -d '{
       "description": "Windows 10 Custom Image",
       "url": "https://your-server.com/win10-custom.raw"
     }'
   ```

3. **Create Instance:**
   ```bash
   # List available snapshots
   curl -X GET "https://api.vultr.com/v2/snapshots" \
     -H "Authorization: Bearer your-api-key"
   
   # Create instance from snapshot
   curl -X POST "https://api.vultr.com/v2/instances" \
     -H "Authorization: Bearer your-api-key" \
     -H "Content-Type: application/json" \
     -d '{
       "region": "ewr",
       "plan": "vc2-2c-4gb",
       "snapshot_id": "your-snapshot-id"
     }'
   ```

## 🔵 Linode

### Requirements
- **Format**: RAW
- **Maximum Size**: Available disk space
- **Architecture**: x64

### Deployment Steps

1. **Prepare Image:**
   ```powershell
   # Convert to RAW format
   .\scripts\Convert-Image.ps1 -SourcePath "output\win10-custom.qcow2" -OutputFormat "raw" -VMName "win10-custom"
   
   # Compress for upload
   gzip output/win10-custom.raw
   ```

2. **Upload via Linode CLI:**
   ```bash
   # Create image
   linode-cli images create \
     --label "Windows 10 Custom" \
     --description "Custom Windows 10 with VirtIO drivers" \
     --cloud_init false
   
   # Upload image file
   linode-cli images upload \
     --image your-image-id \
     --file output/win10-custom.raw.gz
   ```

3. **Create Linode:**
   ```bash
   linode-cli linodes create \
     --type g6-standard-4 \
     --region us-east \
     --image your-image-id \
     --root_pass 'secure-password' \
     --label win10-custom-vm
   ```

## 🔧 Post-Deployment Configuration

### Essential Steps After Deployment

1. **Change Default Passwords:**
   ```cmd
   # Connect via RDP and change passwords
   net user Administrator "NewSecurePassword123!"
   net user clouduser "NewUserPassword123!"
   ```

2. **Update Windows:**
   ```cmd
   # Enable Windows Update
   sc config wuauserv start= auto
   sc start wuauserv
   
   # Check for updates
   powershell "Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
   ```

3. **Configure Firewall:**
   ```cmd
   # Enable Windows Firewall
   netsh advfirewall set allprofiles state on
   
   # Configure RDP access
   netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
   ```

4. **Install Cloud Provider Tools:**
   - **AWS**: AWS CLI, CloudWatch agent
   - **Azure**: Azure CLI, Azure Monitor agent
   - **GCP**: Google Cloud SDK, Stackdriver agent
   - **DigitalOcean**: Monitoring agent

### Security Hardening

```powershell
# Disable unnecessary services
$servicesToDisable = @(
    'Fax', 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc',
    'XboxGipSvc', 'SharedAccess', 'lfsvc', 'MapsBroker'
)

foreach ($service in $servicesToDisable) {
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
}

# Configure automatic updates
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f

# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false
```

## 📊 Performance Optimization

### Cloud-Specific Optimizations

```powershell
# Optimize for cloud environment
function Optimize-ForCloud {
    param($CloudProvider)
    
    switch ($CloudProvider) {
        "AWS" {
            # Enable enhanced networking
            Set-NetAdapterAdvancedProperty -Name "*" -RegistryKeyword "NetworkAddress" -RegistryValue ""
            
            # Optimize TCP settings
            netsh int tcp set global autotuninglevel=normal
            netsh int tcp set global rss=enabled
        }
        
        "Azure" {
            # Azure-specific optimizations
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f
        }
        
        "GCP" {
            # GCP-specific optimizations
            Set-NetAdapterRss -Name "*" -Enabled $true
            Set-NetAdapterChecksumOffload -Name "*" -RxChecksumOffload Enabled -TxChecksumOffload Enabled
        }
        
        "DigitalOcean" {
            # DigitalOcean-specific optimizations
            netsh int tcp set supplemental custom congestionprovider=bbr2
        }
    }
}
```

## 🔄 Image Management

### Version Control

```powershell
# Tag images with versions
function Tag-CloudImage {
    param(
        $ImageName,
        $Version,
        $CloudProvider
    )
    
    $tags = @{
        "Version" = $Version
        "BuildDate" = (Get-Date -Format "yyyy-MM-dd")
        "OS" = "Windows-10"
        "VirtIO" = "Latest"
        "Creator" = "Windows10CustomImageBuilder"
    }
    
    # Apply provider-specific tagging
    switch ($CloudProvider) {
        "AWS" {
            foreach ($key in $tags.Keys) {
                aws ec2 create-tags --resources $ImageName --tags Key=$key,Value=$tags[$key]
            }
        }
        
        "Azure" {
            $tagString = ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
            az image update --name $ImageName --set tags."$tagString"
        }
    }
}
```

### Automated Updates

```yaml
# GitHub Actions workflow example
name: Update Cloud Images
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday

jobs:
  build-and-deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Updated Image
        run: .\scripts\Build-CustomImage.ps1
      - name: Deploy to Clouds
        run: |
          .\scripts\Deploy-ToDigitalOcean.ps1
          .\scripts\Deploy-ToAWS.ps1
          .\scripts\Deploy-ToAzure.ps1
```

## 🚨 Troubleshooting Deployment

### Common Issues

1. **Import Fails:**
   - Check image format compatibility
   - Verify file integrity
   - Ensure proper permissions

2. **Boot Fails:**
   - Check boot loader configuration
   - Verify VirtIO drivers are installed
   - Test image locally first

3. **Network Issues:**
   - Verify VirtIO network drivers
   - Check cloud provider networking settings
   - Test with alternative network configuration

4. **Performance Issues:**
   - Verify VirtIO drivers are active
   - Check cloud provider instance type
   - Monitor resource utilization

### Support Resources

- **Cloud Provider Documentation**
- **Community Forums**
- **GitHub Issues**: Report deployment-specific problems
- **Professional Support**: Available for enterprise deployments

---

**Next**: See [ADVANCED-CONFIG.md](ADVANCED-CONFIG.md) for advanced customization options and enterprise features.
