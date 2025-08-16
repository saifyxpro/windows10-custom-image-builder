<#
.SYNOPSIS
    Sets up the development environment for Windows 10 custom image building.

.DESCRIPTION
    This script installs QEMU, creates necessary directories, and configures
    the environment for building Windows 10 custom images with VirtIO drivers.

.PARAMETER InstallPath
    The installation path for QEMU. Defaults to "C:\Program Files\qemu"

.PARAMETER WorkingDirectory
    The working directory for VM builds. Defaults to current directory.

.PARAMETER SkipQEMUInstall
    Skip QEMU installation if already installed.

.EXAMPLE
    .\Setup-Environment.ps1

.EXAMPLE
    .\Setup-Environment.ps1 -InstallPath "C:\Tools\qemu" -WorkingDirectory "D:\VMBuild"

.NOTES
    Requires Administrator privileges for QEMU installation.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "C:\Program Files\qemu",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = $PSScriptRoot,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipQEMUInstall
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

function Write-StatusMessage {
    param($Message, $Type = "Info")
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green" 
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    Write-Host "[$Type] $Message" -ForegroundColor $colors[$Type]
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-QEMU {
    param($InstallPath)
    
    Write-StatusMessage "Installing QEMU for Windows..." "Info"
    
    # Check if QEMU is already installed
    if (Test-Path "$InstallPath\qemu-system-x86_64.exe") {
        Write-StatusMessage "QEMU already installed at $InstallPath" "Success"
        return
    }
    
    # Download QEMU installer
    $qemuUrl = "https://qemu.weilnetz.de/w64/qemu-w64-setup-20231009.exe"
    $installerPath = "$env:TEMP\qemu-installer.exe"
    
    try {
        Write-StatusMessage "Downloading QEMU installer..." "Info"
        Invoke-WebRequest -Uri $qemuUrl -OutFile $installerPath -UseBasicParsing
        
        Write-StatusMessage "Running QEMU installer..." "Info"
        Start-Process -FilePath $installerPath -ArgumentList "/S", "/D=$InstallPath" -Wait
        
        # Add to PATH if not already there
        $envPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
        if ($envPath -notlike "*$InstallPath*") {
            Write-StatusMessage "Adding QEMU to system PATH..." "Info"
            [Environment]::SetEnvironmentVariable("PATH", "$envPath;$InstallPath", [EnvironmentVariableTarget]::Machine)
        }
        
        Write-StatusMessage "QEMU installation completed successfully!" "Success"
    }
    catch {
        Write-StatusMessage "Failed to install QEMU: $($_.Exception.Message)" "Error"
        throw
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
}

function New-DirectoryStructure {
    param($BaseDirectory)
    
    $directories = @(
        "iso",
        "drivers", 
        "output",
        "temp",
        "logs",
        "config",
        "scripts",
        "docs",
        "templates"
    )
    
    Write-StatusMessage "Creating directory structure..." "Info"
    
    foreach ($dir in $directories) {
        $fullPath = Join-Path $BaseDirectory $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-StatusMessage "Created directory: $fullPath" "Success"
        }
    }
    
    # Create .gitkeep files for empty directories
    $emptyDirs = @("iso", "drivers", "output", "temp", "logs")
    foreach ($dir in $emptyDirs) {
        $gitkeepPath = Join-Path $BaseDirectory "$dir\.gitkeep"
        if (-not (Test-Path $gitkeepPath)) {
            New-Item -ItemType File -Path $gitkeepPath -Force | Out-Null
        }
    }
}

function Test-Prerequisites {
    Write-StatusMessage "Checking prerequisites..." "Info"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.0 or higher is required"
    }
    Write-StatusMessage "PowerShell version: $($PSVersionTable.PSVersion)" "Success"
    
    # Check available disk space (minimum 200GB)
    $drive = (Get-Location).Drive
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq $drive.Name).FreeSpace
    $freeSpaceGB = [Math]::Round($freeSpace / 1GB, 2)
    
    if ($freeSpaceGB -lt 200) {
        Write-StatusMessage "Warning: Only $freeSpaceGB GB free space available. Minimum 200GB recommended." "Warning"
    } else {
        Write-StatusMessage "Available disk space: $freeSpaceGB GB" "Success"
    }
    
    # Check RAM
    $totalRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
    $totalRAMGB = [Math]::Round($totalRAM / 1GB, 2)
    
    if ($totalRAMGB -lt 16) {
        Write-StatusMessage "Warning: Only $totalRAMGB GB RAM available. Minimum 16GB recommended." "Warning"
    } else {
        Write-StatusMessage "Total RAM: $totalRAMGB GB" "Success"
    }
}

function New-ConfigurationFiles {
    param($BaseDirectory)
    
    Write-StatusMessage "Creating default configuration files..." "Info"
    
    # Build configuration
    $buildConfig = @{
        vm = @{
            memory = "8192"
            cpus = "4"
            diskSize = "150G"
            diskFormat = "qcow2"
            accelerator = "tcg"
        }
        windows = @{
            edition = "Pro"
            language = "en-US"
            timezone = "UTC"
            updates = $true
        }
        virtio = @{
            version = "latest"
            components = @("storage", "network", "balloon", "serial")
        }
        output = @{
            formats = @("qcow2", "raw")
            compress = $true
            compression = "gzip"
        }
    }
    
    $configPath = Join-Path $BaseDirectory "config\build-config.json"
    $buildConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Encoding UTF8
    Write-StatusMessage "Created build configuration: $configPath" "Success"
    
    # QEMU parameters
    $qemuParams = @{
        common = @{
            machine = "type=pc,accel=tcg"
            cpu = "qemu64"
            rtc = "base=localtime"
            vga = "std"
            noReboot = $true
        }
        network = @{
            device = "virtio-net"
            netdev = "user,id=net0"
        }
        storage = @{
            interface = "virtio"
            cache = "writeback"
        }
    }
    
    $qemuConfigPath = Join-Path $BaseDirectory "config\qemu-params.json"
    $qemuParams | ConvertTo-Json -Depth 2 | Set-Content -Path $qemuConfigPath -Encoding UTF8
    Write-StatusMessage "Created QEMU parameters: $qemuConfigPath" "Success"
}

# Main execution
try {
    Write-StatusMessage "Windows 10 Custom Image Builder - Environment Setup" "Info"
    Write-StatusMessage "=============================================" "Info"
    
    # Check administrator rights
    if (-not (Test-AdminRights)) {
        throw "This script requires Administrator privileges for QEMU installation."
    }
    
    # Test prerequisites
    Test-Prerequisites
    
    # Install QEMU if not skipped
    if (-not $SkipQEMUInstall) {
        Install-QEMU -InstallPath $InstallPath
    } else {
        Write-StatusMessage "Skipping QEMU installation as requested." "Info"
    }
    
    # Create directory structure
    New-DirectoryStructure -BaseDirectory $WorkingDirectory
    
    # Create configuration files
    New-ConfigurationFiles -BaseDirectory $WorkingDirectory
    
    Write-StatusMessage "Environment setup completed successfully!" "Success"
    Write-StatusMessage "Next steps:" "Info"
    Write-StatusMessage "1. Run .\scripts\Download-Prerequisites.ps1 to download ISOs" "Info"
    Write-StatusMessage "2. Run .\scripts\Build-CustomImage.ps1 to start building" "Info"
}
catch {
    Write-StatusMessage "Setup failed: $($_.Exception.Message)" "Error"
    exit 1
}
