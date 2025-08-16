<#
.SYNOPSIS
    Orchestrates the complete Windows 10 custom image building process.

.DESCRIPTION
    This script manages the entire workflow for creating a Windows 10 custom image
    with VirtIO drivers optimized for cloud deployment.

.PARAMETER ConfigFile
    Path to build configuration JSON file. Defaults to config\build-config.json

.PARAMETER VMName
    Name for the virtual machine and output files. Defaults to "win10-custom"

.PARAMETER SkipInstallation
    Skip Windows installation phase (if VM already exists and is at configuration stage)

.PARAMETER SkipConfiguration
    Skip Windows configuration phase

.PARAMETER SkipSysprep
    Skip Sysprep generalization phase

.PARAMETER OutputFormats
    Array of output formats to generate. Options: qcow2, raw, vhd, vmdk

.EXAMPLE
    .\Build-CustomImage.ps1

.EXAMPLE
    .\Build-CustomImage.ps1 -VMName "windows10-enterprise" -OutputFormats @("raw", "vhd")

.NOTES
    This script requires Administrator privileges and significant time/resources.
    Expected build time: 2-4 hours depending on hardware and configuration.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "config\build-config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$VMName = "win10-custom",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipInstallation,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfiguration,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSysprep,
    
    [Parameter(Mandatory = $false)]
    [string[]]$OutputFormats = @("qcow2", "raw")
)

# Import required functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$scriptPath\Install-VirtIODrivers.ps1"
. "$scriptPath\Configure-Windows.ps1"
. "$scriptPath\Convert-Image.ps1"

function Write-StatusMessage {
    param($Message, $Type = "Info")
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green" 
        "Warning" = "Yellow"
        "Error" = "Red"
        "Phase" = "Magenta"
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Type] $Message" -ForegroundColor $colors[$Type]
}

function Read-BuildConfiguration {
    param($ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        Write-StatusMessage "Build configuration loaded from: $ConfigPath" "Success"
        return $config
    }
    catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

function Test-Prerequisites {
    param($Config)
    
    Write-StatusMessage "Checking prerequisites..." "Info"
    
    # Check required files
    $windowsISO = "iso\windows10.iso"
    $virtIOISO = "iso\virtio-win.iso"
    
    if (-not (Test-Path $windowsISO)) {
        throw "Windows 10 ISO not found: $windowsISO"
    }
    
    if (-not (Test-Path $virtIOISO)) {
        throw "VirtIO drivers ISO not found: $virtIOISO"
    }
    
    Write-StatusMessage "Windows 10 ISO: Found" "Success"
    Write-StatusMessage "VirtIO ISO: Found" "Success"
    
    # Check QEMU installation
    $qemuExe = Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue
    if (-not $qemuExe) {
        throw "QEMU not found in PATH. Please run Setup-Environment.ps1 first."
    }
    Write-StatusMessage "QEMU: Found at $($qemuExe.Source)" "Success"
    
    # Check available resources
    $totalRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $vmRAM = [int]$Config.vm.memory / 1024
    
    if ($totalRAM -lt ($vmRAM + 4)) {
        Write-StatusMessage "Warning: Low system RAM. VM requires $vmRAM GB, system has $([Math]::Round($totalRAM, 1)) GB" "Warning"
    }
    
    # Check disk space
    $drive = (Get-Location).Drive
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk | Where-Object DeviceID -eq $drive.Name).FreeSpace / 1GB
    $requiredSpace = 200 # GB
    
    if ($freeSpace -lt $requiredSpace) {
        Write-StatusMessage "Warning: Low disk space. Required: $requiredSpace GB, Available: $([Math]::Round($freeSpace, 1)) GB" "Warning"
    }
}

function New-VirtualDisk {
    param($VMName, $Config)
    
    Write-StatusMessage "Creating virtual disk..." "Info"
    
    $diskPath = "output\$VMName.qcow2"
    
    if (Test-Path $diskPath) {
        Write-StatusMessage "Virtual disk already exists: $diskPath" "Warning"
        $response = Read-Host "Do you want to recreate it? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-StatusMessage "Using existing virtual disk" "Info"
            return $diskPath
        }
        Remove-Item $diskPath -Force
    }
    
    # Create QCOW2 disk
    $createArgs = @(
        "create",
        "-f", $Config.vm.diskFormat,
        $diskPath,
        $Config.vm.diskSize
    )
    
    Write-StatusMessage "Running: qemu-img $($createArgs -join ' ')" "Info"
    & qemu-img @createArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create virtual disk"
    }
    
    Write-StatusMessage "Virtual disk created: $diskPath ($($Config.vm.diskSize))" "Success"
    return $diskPath
}

function Start-WindowsInstallation {
    param($VMName, $Config, $DiskPath)
    
    Write-StatusMessage "Starting Windows installation phase..." "Phase"
    
    # Build QEMU command arguments
    $qemuArgs = @(
        "-m", $Config.vm.memory,
        "-smp", $Config.vm.cpus,
        "-machine", "type=pc,accel=$($Config.vm.accelerator)",
        "-cpu", "qemu64",
        "-drive", "file=$DiskPath,format=$($Config.vm.diskFormat),if=virtio,cache=writeback",
        "-drive", "file=iso\windows10.iso,media=cdrom,index=0",
        "-drive", "file=iso\virtio-win.iso,media=cdrom,index=1",
        "-boot", "order=dc",
        "-vga", "std",
        "-device", "virtio-net,netdev=net0",
        "-netdev", "user,id=net0",
        "-rtc", "base=localtime",
        "-no-reboot"
    )
    
    Write-StatusMessage "Starting QEMU for Windows installation..." "Info"
    Write-StatusMessage "VM will open in a new window. Please complete Windows installation." "Info"
    Write-StatusMessage "IMPORTANT: Install VirtIO storage driver when prompted for disk location!" "Warning"
    
    # Log the command
    $logPath = "logs\qemu-install-$VMName-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    "QEMU Installation Command:`nqemu-system-x86_64.exe $($qemuArgs -join ' ')" | Set-Content -Path $logPath
    
    # Start QEMU process
    try {
        $process = Start-Process -FilePath "qemu-system-x86_64.exe" -ArgumentList $qemuArgs -PassThru
        
        Write-StatusMessage "QEMU process started (PID: $($process.Id))" "Success"
        Write-StatusMessage "Waiting for Windows installation to complete..." "Info"
        Write-StatusMessage "The VM will automatically shut down when installation is finished" "Info"
        
        # Wait for process to exit
        $process.WaitForExit()
        
        if ($process.ExitCode -eq 0) {
            Write-StatusMessage "Windows installation completed successfully!" "Success"
        } else {
            throw "QEMU process exited with code: $($process.ExitCode)"
        }
    }
    catch {
        throw "Failed to start Windows installation: $($_.Exception.Message)"
    }
}

function Start-WindowsConfiguration {
    param($VMName, $Config, $DiskPath)
    
    Write-StatusMessage "Starting Windows configuration phase..." "Phase"
    
    # Build QEMU command for configuration
    $qemuArgs = @(
        "-m", $Config.vm.memory,
        "-smp", $Config.vm.cpus,
        "-machine", "type=pc,accel=$($Config.vm.accelerator)",
        "-cpu", "qemu64",
        "-drive", "file=$DiskPath,format=$($Config.vm.diskFormat),if=virtio,cache=writeback",
        "-boot", "c",
        "-vga", "std",
        "-device", "virtio-net,netdev=net0",
        "-netdev", "user,id=net0,hostfwd=tcp::3389-:3389",
        "-rtc", "base=localtime"
    )
    
    Write-StatusMessage "Starting QEMU for Windows configuration..." "Info"
    Write-StatusMessage "VM will open in a new window. Please complete the configuration steps." "Info"
    Write-StatusMessage "RDP will be available on localhost:3389 once configured" "Info"
    
    # Start QEMU process in background for configuration
    try {
        $process = Start-Process -FilePath "qemu-system-x86_64.exe" -ArgumentList $qemuArgs -PassThru
        
        Write-StatusMessage "QEMU process started (PID: $($process.Id))" "Success"
        Write-StatusMessage "Please complete Windows configuration and then shut down the VM" "Info"
        Write-StatusMessage "Press Enter when Windows configuration is complete and VM is shut down..." "Warning"
        Read-Host
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-StatusMessage "Stopping QEMU process..." "Info"
            $process.Kill()
            $process.WaitForExit(30)
        }
        
        Write-StatusMessage "Windows configuration phase completed!" "Success"
    }
    catch {
        throw "Failed during Windows configuration: $($_.Exception.Message)"
    }
}

function Start-SysprepProcess {
    param($VMName, $Config, $DiskPath)
    
    Write-StatusMessage "Starting Sysprep generalization phase..." "Phase"
    
    # Build QEMU command for Sysprep
    $qemuArgs = @(
        "-m", $Config.vm.memory,
        "-smp", $Config.vm.cpus,
        "-machine", "type=pc,accel=$($Config.vm.accelerator)",
        "-cpu", "qemu64",
        "-drive", "file=$DiskPath,format=$($Config.vm.diskFormat),if=virtio,cache=writeback",
        "-boot", "c",
        "-vga", "std",
        "-device", "virtio-net,netdev=net0",
        "-netdev", "user,id=net0,hostfwd=tcp::3389-:3389",
        "-rtc", "base=localtime"
    )
    
    Write-StatusMessage "Starting QEMU for Sysprep..." "Info"
    Write-StatusMessage "Please run Sysprep with /generalize /oobe /shutdown options" "Warning"
    Write-StatusMessage "Example: C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown" "Info"
    
    try {
        $process = Start-Process -FilePath "qemu-system-x86_64.exe" -ArgumentList $qemuArgs -PassThru
        
        Write-StatusMessage "QEMU process started (PID: $($process.Id))" "Success"
        Write-StatusMessage "VM will automatically shut down after Sysprep completes" "Info"
        
        # Wait for process to exit (Sysprep will shutdown the VM)
        $process.WaitForExit()
        
        Write-StatusMessage "Sysprep phase completed!" "Success"
    }
    catch {
        throw "Failed during Sysprep process: $($_.Exception.Message)"
    }
}

function Test-VMBoot {
    param($VMName, $Config, $DiskPath)
    
    Write-StatusMessage "Testing VM boot..." "Info"
    
    $response = Read-Host "Do you want to test the VM boot before finalizing? (Y/n)"
    if ($response -eq 'n' -or $response -eq 'N') {
        Write-StatusMessage "Skipping boot test" "Info"
        return
    }
    
    # Build QEMU command for testing
    $qemuArgs = @(
        "-m", $Config.vm.memory,
        "-smp", $Config.vm.cpus,
        "-machine", "type=pc,accel=$($Config.vm.accelerator)",
        "-cpu", "qemu64",
        "-drive", "file=$DiskPath,format=$($Config.vm.diskFormat),if=virtio,cache=writeback",
        "-boot", "c",
        "-vga", "std",
        "-device", "virtio-net,netdev=net0",
        "-netdev", "user,id=net0",
        "-rtc", "base=localtime"
    )
    
    Write-StatusMessage "Starting test boot..." "Info"
    Write-StatusMessage "Verify that Windows boots to OOBE and shut down when ready" "Info"
    
    try {
        $process = Start-Process -FilePath "qemu-system-x86_64.exe" -ArgumentList $qemuArgs -PassThru
        
        Write-StatusMessage "Test VM started (PID: $($process.Id))" "Success"
        Write-StatusMessage "Press Enter when you've finished testing and shut down the VM..." "Warning"
        Read-Host
        
        # Check if process is still running
        if (-not $process.HasExited) {
            Write-StatusMessage "Stopping test VM..." "Info"
            $process.Kill()
            $process.WaitForExit(30)
        }
        
        Write-StatusMessage "Boot test completed!" "Success"
    }
    catch {
        Write-StatusMessage "Boot test failed: $($_.Exception.Message)" "Error"
    }
}

function New-BuildSummary {
    param($VMName, $Config, $DiskPath, $OutputFormats, $StartTime)
    
    $endTime = Get-Date
    $duration = $endTime - $StartTime
    
    Write-StatusMessage "Build Summary" "Phase"
    Write-StatusMessage "=============" "Phase"
    Write-StatusMessage "VM Name: $VMName" "Info"
    Write-StatusMessage "Build Duration: $($duration.ToString('hh\:mm\:ss'))" "Info"
    Write-StatusMessage "Source Disk: $DiskPath" "Info"
    
    # List output files
    Write-StatusMessage "Output Files:" "Info"
    foreach ($format in $OutputFormats) {
        $outputFile = "output\$VMName.$format"
        if (Test-Path $outputFile) {
            $fileSize = [Math]::Round((Get-Item $outputFile).Length / 1GB, 2)
            Write-StatusMessage "  - $outputFile ($fileSize GB)" "Success"
        }
    }
    
    # Check for compressed files
    $compressedFiles = Get-ChildItem "output\$VMName.*" -Include "*.gz", "*.zip", "*.7z"
    if ($compressedFiles) {
        Write-StatusMessage "Compressed Files:" "Info"
        foreach ($file in $compressedFiles) {
            $fileSize = [Math]::Round($file.Length / 1MB, 2)
            Write-StatusMessage "  - $($file.Name) ($fileSize MB)" "Success"
        }
    }
}

# Main execution
try {
    $startTime = Get-Date
    
    Write-StatusMessage "Windows 10 Custom Image Builder" "Phase"
    Write-StatusMessage "===============================" "Phase"
    Write-StatusMessage "VM Name: $VMName" "Info"
    Write-StatusMessage "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" "Info"
    
    # Load configuration
    $config = Read-BuildConfiguration -ConfigPath $ConfigFile
    
    # Test prerequisites
    Test-Prerequisites -Config $config
    
    # Create output directories
    @("output", "logs", "temp") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    # Create virtual disk
    $diskPath = New-VirtualDisk -VMName $VMName -Config $config
    
    # Phase 1: Windows Installation
    if (-not $SkipInstallation) {
        Start-WindowsInstallation -VMName $VMName -Config $config -DiskPath $diskPath
    } else {
        Write-StatusMessage "Skipping Windows installation phase" "Warning"
    }
    
    # Phase 2: Windows Configuration
    if (-not $SkipConfiguration) {
        Start-WindowsConfiguration -VMName $VMName -Config $config -DiskPath $diskPath
    } else {
        Write-StatusMessage "Skipping Windows configuration phase" "Warning"
    }
    
    # Phase 3: Sysprep
    if (-not $SkipSysprep) {
        Start-SysprepProcess -VMName $VMName -Config $config -DiskPath $diskPath
    } else {
        Write-StatusMessage "Skipping Sysprep phase" "Warning"
    }
    
    # Phase 4: Test Boot (optional)
    Test-VMBoot -VMName $VMName -Config $config -DiskPath $diskPath
    
    # Phase 5: Convert to output formats
    Write-StatusMessage "Converting to output formats..." "Phase"
    foreach ($format in $OutputFormats) {
        if ($format -ne $config.vm.diskFormat) {
            Convert-VMImage -SourcePath $diskPath -OutputFormat $format -VMName $VMName
        }
    }
    
    # Phase 6: Compression (if enabled)
    if ($config.output.compress) {
        Write-StatusMessage "Compressing output files..." "Phase"
        foreach ($format in $OutputFormats) {
            $outputFile = "output\$VMName.$format"
            if (Test-Path $outputFile) {
                Compress-VMImage -SourcePath $outputFile -CompressionType $config.output.compression
            }
        }
    }
    
    # Generate build summary
    New-BuildSummary -VMName $VMName -Config $config -DiskPath $diskPath -OutputFormats $OutputFormats -StartTime $startTime
    
    Write-StatusMessage "Custom image build completed successfully!" "Success"
    Write-StatusMessage "Files are ready for cloud deployment." "Info"
    
}
catch {
    Write-StatusMessage "Build failed: $($_.Exception.Message)" "Error"
    Write-StatusMessage "Check logs directory for detailed error information" "Info"
    exit 1
}
