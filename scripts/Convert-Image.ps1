<#
.SYNOPSIS
    Converts VM images between different formats for cloud deployment.

.DESCRIPTION
    This script converts QCOW2 images to various formats required by different
    cloud providers (RAW, VHD, VMDK) and optionally compresses them.

.PARAMETER SourcePath
    Path to the source image file (typically QCOW2)

.PARAMETER OutputFormat
    Target format for conversion (raw, vhd, vmdk, vdi)

.PARAMETER VMName
    Name prefix for output files

.PARAMETER OutputPath
    Custom output path. If not specified, uses output directory.

.PARAMETER Compress
    Compress the output file after conversion

.EXAMPLE
    Convert-VMImage -SourcePath "output\win10.qcow2" -OutputFormat "raw" -VMName "win10-custom"

.NOTES
    Requires qemu-img tool to be available in PATH.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("raw", "vhd", "vmdk", "vdi", "qcow2")]
    [string]$OutputFormat,
    
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Compress
)

function Write-StatusMessage {
    param($Message, $Type = "Info")
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green" 
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$Type] $Message" -ForegroundColor $colors[$Type]
}

function Convert-VMImage {
    param(
        [string]$SourcePath,
        [string]$OutputFormat,
        [string]$VMName,
        [string]$OutputPath
    )
    
    Write-StatusMessage "Starting image conversion..." "Info"
    Write-StatusMessage "Source: $SourcePath" "Info"
    Write-StatusMessage "Format: $OutputFormat" "Info"
    
    # Validate source file
    if (-not (Test-Path $SourcePath)) {
        throw "Source file not found: $SourcePath"
    }
    
    # Get source file info
    try {
        $sourceInfo = & qemu-img info $SourcePath --output json | ConvertFrom-Json
        Write-StatusMessage "Source format: $($sourceInfo.'format')" "Info"
        Write-StatusMessage "Virtual size: $([Math]::Round($sourceInfo.'virtual-size' / 1GB, 2)) GB" "Info"
        Write-StatusMessage "Actual size: $([Math]::Round($sourceInfo.'actual-size' / 1GB, 2)) GB" "Info"
    }
    catch {
        Write-StatusMessage "Could not get source image info: $($_.Exception.Message)" "Warning"
    }
    
    # Set output path
    if (-not $OutputPath) {
        $OutputPath = "output\$VMName.$OutputFormat"
    }
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Check if output file already exists
    if (Test-Path $OutputPath) {
        Write-StatusMessage "Output file already exists: $OutputPath" "Warning"
        $response = Read-Host "Do you want to overwrite it? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-StatusMessage "Conversion cancelled by user" "Info"
            return $false
        }
        Remove-Item $OutputPath -Force
    }
    
    # Build conversion command
    $convertArgs = @(
        "convert",
        "-p",  # Show progress
        "-f", $sourceInfo.format,
        "-O", $OutputFormat
    )
    
    # Add format-specific options
    switch ($OutputFormat) {
        "vhd" {
            $convertArgs += @("-o", "subformat=fixed")
            Write-StatusMessage "Using fixed VHD subformat for cloud compatibility" "Info"
        }
        "vmdk" {
            $convertArgs += @("-o", "subformat=streamOptimized")
            Write-StatusMessage "Using streamOptimized VMDK subformat" "Info"
        }
        "qcow2" {
            $convertArgs += @("-o", "cluster_size=65536,lazy_refcounts=on")
            Write-StatusMessage "Using optimized QCOW2 options" "Info"
        }
    }
    
    $convertArgs += @($SourcePath, $OutputPath)
    
    Write-StatusMessage "Running: qemu-img $($convertArgs -join ' ')" "Info"
    
    try {
        $startTime = Get-Date
        & qemu-img @convertArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "qemu-img conversion failed with exit code: $LASTEXITCODE"
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # Verify output file
        if (Test-Path $OutputPath) {
            $outputSize = [Math]::Round((Get-Item $OutputPath).Length / 1GB, 2)
            Write-StatusMessage "Conversion completed successfully!" "Success"
            Write-StatusMessage "Output file: $OutputPath" "Success"
            Write-StatusMessage "Output size: $outputSize GB" "Info"
            Write-StatusMessage "Conversion time: $($duration.ToString('hh\:mm\:ss'))" "Info"
            return $true
        } else {
            throw "Output file was not created"
        }
    }
    catch {
        Write-StatusMessage "Conversion failed: $($_.Exception.Message)" "Error"
        throw
    }
}

function Compress-VMImage {
    param(
        [string]$SourcePath,
        [string]$CompressionType = "gzip"
    )
    
    Write-StatusMessage "Starting image compression..." "Info"
    Write-StatusMessage "Source: $SourcePath" "Info"
    Write-StatusMessage "Compression: $CompressionType" "Info"
    
    if (-not (Test-Path $SourcePath)) {
        throw "Source file not found: $SourcePath"
    }
    
    $sourceSize = [Math]::Round((Get-Item $SourcePath).Length / 1GB, 2)
    $startTime = Get-Date
    
    switch ($CompressionType.ToLower()) {
        "gzip" {
            $compressedPath = "$SourcePath.gz"
            Write-StatusMessage "Compressing with gzip..." "Info"
            
            try {
                # Use PowerShell's built-in compression for gzip
                $sourceBytes = [System.IO.File]::ReadAllBytes($SourcePath)
                $compressedBytes = [System.IO.Compression.GZipStream]::new(
                    [System.IO.File]::Create($compressedPath),
                    [System.IO.Compression.CompressionMode]::Compress
                )
                $compressedBytes.Write($sourceBytes, 0, $sourceBytes.Length)
                $compressedBytes.Close()
                
                # Alternative: Use 7-Zip if available
                $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
                if ($sevenZip -and (Test-Path $compressedPath)) {
                    Remove-Item $compressedPath -Force
                    & "7z.exe" a -tgzip "$compressedPath" "$SourcePath"
                }
            }
            catch {
                # Fallback to tar command
                try {
                    & tar -czf $compressedPath -C (Split-Path $SourcePath -Parent) (Split-Path $SourcePath -Leaf)
                }
                catch {
                    Write-StatusMessage "Gzip compression failed, trying alternative methods..." "Warning"
                    throw
                }
            }
        }
        
        "zip" {
            $compressedPath = "$SourcePath.zip"
            Write-StatusMessage "Compressing with ZIP..." "Info"
            
            Compress-Archive -Path $SourcePath -DestinationPath $compressedPath -Force
        }
        
        "7z" {
            $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
            if (-not $sevenZip) {
                throw "7-Zip not found in PATH. Please install 7-Zip or use different compression type."
            }
            
            $compressedPath = "$SourcePath.7z"
            Write-StatusMessage "Compressing with 7-Zip..." "Info"
            
            & "7z.exe" a -t7z -mx=9 $compressedPath $SourcePath
            
            if ($LASTEXITCODE -ne 0) {
                throw "7-Zip compression failed"
            }
        }
        
        default {
            throw "Unsupported compression type: $CompressionType"
        }
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    if (Test-Path $compressedPath) {
        $compressedSize = [Math]::Round((Get-Item $compressedPath).Length / 1MB, 2)
        $compressionRatio = [Math]::Round((1 - ($compressedSize / 1024) / $sourceSize) * 100, 1)
        
        Write-StatusMessage "Compression completed successfully!" "Success"
        Write-StatusMessage "Compressed file: $compressedPath" "Success"
        Write-StatusMessage "Original size: $sourceSize GB" "Info"
        Write-StatusMessage "Compressed size: $compressedSize MB" "Info"
        Write-StatusMessage "Compression ratio: $compressionRatio%" "Info"
        Write-StatusMessage "Compression time: $($duration.ToString('hh\:mm\:ss'))" "Info"
        
        return $compressedPath
    } else {
        throw "Compressed file was not created"
    }
}

function Test-CloudCompatibility {
    param(
        [string]$ImagePath,
        [string]$Format,
        [string]$CloudProvider
    )
    
    Write-StatusMessage "Testing cloud compatibility..." "Info"
    
    # Get image information
    try {
        $imageInfo = & qemu-img info $ImagePath --output json | ConvertFrom-Json
    }
    catch {
        Write-StatusMessage "Could not get image information" "Error"
        return $false
    }
    
    $compatible = $true
    $recommendations = @()
    
    # Provider-specific checks
    switch ($CloudProvider.ToLower()) {
        "digitalocean" {
            if ($Format -notin @("raw", "vhd")) {
                $compatible = $false
                $recommendations += "DigitalOcean supports RAW and VHD formats"
            }
        }
        
        "aws" {
            if ($Format -notin @("vhd", "vmdk", "raw")) {
                $compatible = $false
                $recommendations += "AWS EC2 prefers VHD or VMDK formats"
            }
        }
        
        "azure" {
            if ($Format -ne "vhd") {
                $compatible = $false
                $recommendations += "Azure requires VHD format with fixed subformat"
            }
        }
        
        "gcp" {
            if ($Format -notin @("raw", "vmdk")) {
                $compatible = $false
                $recommendations += "Google Cloud Platform supports RAW and VMDK formats"
            }
        }
    }
    
    # General checks
    $sizeGB = [Math]::Round($imageInfo.'virtual-size' / 1GB, 2)
    if ($sizeGB -gt 1024) {
        $compatible = $false
        $recommendations += "Image size ($sizeGB GB) exceeds typical cloud limits (1TB)"
    }
    
    if ($compatible) {
        Write-StatusMessage "Image is compatible with $CloudProvider" "Success"
    } else {
        Write-StatusMessage "Image may not be compatible with $CloudProvider" "Warning"
        foreach ($rec in $recommendations) {
            Write-StatusMessage "Recommendation: $rec" "Warning"
        }
    }
    
    return $compatible
}

# Main execution
try {
    Write-StatusMessage "VM Image Conversion Tool" "Info"
    Write-StatusMessage "=======================" "Info"
    
    # Convert image
    $success = Convert-VMImage -SourcePath $SourcePath -OutputFormat $OutputFormat -VMName $VMName -OutputPath $OutputPath
    
    if ($success) {
        $outputFile = if ($OutputPath) { $OutputPath } else { "output\$VMName.$OutputFormat" }
        
        # Test cloud compatibility
        Test-CloudCompatibility -ImagePath $outputFile -Format $OutputFormat -CloudProvider "digitalocean"
        Test-CloudCompatibility -ImagePath $outputFile -Format $OutputFormat -CloudProvider "aws"
        
        # Compress if requested
        if ($Compress) {
            $compressedFile = Compress-VMImage -SourcePath $outputFile -CompressionType "gzip"
            Write-StatusMessage "Ready for upload: $compressedFile" "Success"
        } else {
            Write-StatusMessage "Ready for upload: $outputFile" "Success"
        }
        
        # Provide cloud-specific upload hints
        Write-StatusMessage "Cloud Upload Hints:" "Info"
        Write-StatusMessage "- DigitalOcean: Upload to publicly accessible URL, then import via Control Panel" "Info"
        Write-StatusMessage "- AWS: Upload to S3, then use EC2 ImportSnapshot API" "Info"
        Write-StatusMessage "- Azure: Upload VHD to Storage Account, then create managed disk" "Info"
        Write-StatusMessage "- GCP: Upload to Cloud Storage, then use 'gcloud compute images create'" "Info"
    }
}
catch {
    Write-StatusMessage "Conversion failed: $($_.Exception.Message)" "Error"
    exit 1
}

# Export functions for use by other scripts
Export-ModuleMember -Function Convert-VMImage, Compress-VMImage, Test-CloudCompatibility
