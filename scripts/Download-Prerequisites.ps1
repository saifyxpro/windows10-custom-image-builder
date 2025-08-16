<#
.SYNOPSIS
    Downloads Windows 10 ISO and VirtIO drivers required for custom image building.

.DESCRIPTION
    This script downloads the Windows 10 installation media and VirtIO drivers
    required for creating optimized virtual machine images.

.PARAMETER WindowsISO
    URL or path to Windows 10 ISO. If not provided, user must download manually.

.PARAMETER VirtIOURL
    URL to VirtIO drivers ISO. Defaults to latest stable version.

.PARAMETER OutputDirectory
    Directory to store downloaded files. Defaults to .\iso

.PARAMETER Force
    Force re-download even if files already exist.

.EXAMPLE
    .\Download-Prerequisites.ps1

.EXAMPLE
    .\Download-Prerequisites.ps1 -WindowsISO "C:\Downloads\windows10.iso" -Force

.NOTES
    Windows 10 ISO must be obtained legally through Microsoft channels.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$WindowsISO,
    
    [Parameter(Mandatory = $false)]
    [string]$VirtIOURL = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ".\iso",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

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

function Get-FileSize {
    param($FilePath)
    if (Test-Path $FilePath) {
        $size = (Get-Item $FilePath).Length
        return [Math]::Round($size / 1MB, 2)
    }
    return 0
}

function Invoke-FileDownload {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )
    
    try {
        Write-StatusMessage "Downloading $Description..." "Info"
        Write-StatusMessage "URL: $Url" "Info"
        Write-StatusMessage "Output: $OutputPath" "Info"
        
        # Create progress callback
        $progressPreference = $ProgressPreference
        $ProgressPreference = 'Continue'
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadProgressChanged += {
            param($sender, $e)
            Write-Progress -Activity "Downloading $Description" `
                          -Status "$($e.BytesReceived / 1MB) MB / $($e.TotalBytesToReceive / 1MB) MB" `
                          -PercentComplete $e.ProgressPercentage
        }
        
        $webClient.DownloadFileCompleted += {
            param($sender, $e)
            Write-Progress -Activity "Downloading $Description" -Completed
        }
        
        # Start download
        $task = $webClient.DownloadFileTaskAsync($Url, $OutputPath)
        $task.Wait()
        
        if ($task.Exception) {
            throw $task.Exception
        }
        
        $ProgressPreference = $progressPreference
        Write-StatusMessage "$Description downloaded successfully!" "Success"
        
        # Verify file size
        $fileSize = Get-FileSize -FilePath $OutputPath
        Write-StatusMessage "File size: $fileSize MB" "Info"
        
    }
    catch {
        Write-StatusMessage "Failed to download $Description : $($_.Exception.Message)" "Error"
        throw
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

function Get-LatestVirtIOVersion {
    try {
        Write-StatusMessage "Checking for latest VirtIO version..." "Info"
        
        # Try to get the latest version from the directory listing
        $baseUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/"
        $response = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing
        
        # Look for version directories
        $versions = $response.Content | Select-String -Pattern 'href="(\d+\.\d+\.\d+)/"' -AllMatches
        
        if ($versions.Matches.Count -gt 0) {
            $latestVersion = $versions.Matches | 
                ForEach-Object { $_.Groups[1].Value } | 
                Sort-Object { [Version]$_ } -Descending | 
                Select-Object -First 1
            
            $latestUrl = "$baseUrl$latestVersion/virtio-win.iso"
            Write-StatusMessage "Latest VirtIO version found: $latestVersion" "Success"
            return $latestUrl
        } else {
            Write-StatusMessage "Could not determine latest version, using default URL" "Warning"
            return $VirtIOURL
        }
    }
    catch {
        Write-StatusMessage "Could not check for latest version, using default URL" "Warning"
        return $VirtIOURL
    }
}

function Test-ISOFile {
    param($FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    # Basic size check (ISOs should be at least 100MB)
    $fileSize = Get-FileSize -FilePath $FilePath
    if ($fileSize -lt 100) {
        Write-StatusMessage "Warning: $FilePath appears to be corrupted (size: $fileSize MB)" "Warning"
        return $false
    }
    
    return $true
}

function Show-WindowsISOInstructions {
    Write-StatusMessage "Windows 10 ISO Download Instructions" "Info"
    Write-StatusMessage "====================================" "Info"
    Write-StatusMessage "1. Visit: https://www.microsoft.com/software-download/windows10" "Info"
    Write-StatusMessage "2. Click 'Download tool now' to get Media Creation Tool" "Info"
    Write-StatusMessage "3. Run the tool and select 'Create installation media'" "Info"
    Write-StatusMessage "4. Choose 'ISO file' option" "Info"
    Write-StatusMessage "5. Save the ISO as 'windows10.iso' in the iso folder" "Info"
    Write-StatusMessage "" "Info"
    Write-StatusMessage "Alternative (requires license):" "Info"
    Write-StatusMessage "1. Visit: https://www.microsoft.com/evalcenter/evaluate-windows-10-enterprise" "Info"
    Write-StatusMessage "2. Download Windows 10 Enterprise evaluation (90-day trial)" "Info"
    Write-StatusMessage "" "Info"
}

# Main execution
try {
    Write-StatusMessage "Windows 10 Custom Image Builder - Download Prerequisites" "Info"
    Write-StatusMessage "=======================================================" "Info"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-StatusMessage "Created directory: $OutputDirectory" "Success"
    }
    
    # Define file paths
    $virtIOPath = Join-Path $OutputDirectory "virtio-win.iso"
    $windowsISOPath = Join-Path $OutputDirectory "windows10.iso"
    
    # Download VirtIO drivers
    $downloadVirtIO = $Force -or (-not (Test-ISOFile -FilePath $virtIOPath))
    
    if ($downloadVirtIO) {
        Write-StatusMessage "VirtIO drivers download required" "Info"
        
        # Get latest version URL
        $latestVirtIOURL = Get-LatestVirtIOVersion
        
        # Remove existing file if corrupted
        if (Test-Path $virtIOPath) {
            Remove-Item $virtIOPath -Force
        }
        
        # Download VirtIO ISO
        Invoke-FileDownload -Url $latestVirtIOURL -OutputPath $virtIOPath -Description "VirtIO drivers"
        
        # Verify download
        if (Test-ISOFile -FilePath $virtIOPath) {
            Write-StatusMessage "VirtIO ISO verified successfully" "Success"
        } else {
            throw "VirtIO ISO verification failed"
        }
    } else {
        Write-StatusMessage "VirtIO drivers already present: $virtIOPath" "Success"
        $fileSize = Get-FileSize -FilePath $virtIOPath
        Write-StatusMessage "File size: $fileSize MB" "Info"
    }
    
    # Handle Windows 10 ISO
    if ($WindowsISO) {
        if (Test-Path $WindowsISO) {
            # Copy from provided path
            Write-StatusMessage "Copying Windows 10 ISO from: $WindowsISO" "Info"
            Copy-Item -Path $WindowsISO -Destination $windowsISOPath -Force
            Write-StatusMessage "Windows 10 ISO copied successfully" "Success"
        } else {
            Write-StatusMessage "Provided Windows ISO path does not exist: $WindowsISO" "Error"
        }
    } else {
        # Check if Windows ISO already exists
        if (Test-ISOFile -FilePath $windowsISOPath) {
            Write-StatusMessage "Windows 10 ISO already present: $windowsISOPath" "Success"
            $fileSize = Get-FileSize -FilePath $windowsISOPath
            Write-StatusMessage "File size: $fileSize MB" "Info"
        } else {
            Write-StatusMessage "Windows 10 ISO not found" "Warning"
            Show-WindowsISOInstructions
            Write-StatusMessage "Please download Windows 10 ISO and save it as: $windowsISOPath" "Info"
        }
    }
    
    # Summary
    Write-StatusMessage "Download status summary:" "Info"
    Write-StatusMessage "======================" "Info"
    
    $virtIOExists = Test-ISOFile -FilePath $virtIOPath
    $windowsExists = Test-ISOFile -FilePath $windowsISOPath
    
    Write-StatusMessage "VirtIO drivers: $(if ($virtIOExists) { 'Ready' } else { 'Missing' })" $(if ($virtIOExists) { 'Success' } else { 'Error' })
    Write-StatusMessage "Windows 10 ISO: $(if ($windowsExists) { 'Ready' } else { 'Missing' })" $(if ($windowsExists) { 'Success' } else { 'Warning' })
    
    if ($virtIOExists -and $windowsExists) {
        Write-StatusMessage "All prerequisites downloaded successfully!" "Success"
        Write-StatusMessage "Next step: Run .\scripts\Build-CustomImage.ps1" "Info"
    } elseif ($virtIOExists) {
        Write-StatusMessage "VirtIO drivers ready. Please download Windows 10 ISO to continue." "Warning"
    } else {
        Write-StatusMessage "Please ensure all required files are downloaded before proceeding." "Error"
    }
    
}
catch {
    Write-StatusMessage "Download failed: $($_.Exception.Message)" "Error"
    exit 1
}
