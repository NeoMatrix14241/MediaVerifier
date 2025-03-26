# Script configuration
param(
    [Parameter(Mandatory=$false)]
    [string]$ScanPath = (Get-Location).Path,
    [Parameter(Mandatory=$false)]
    [int]$MaxParallelJobs = 3
)

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Check if ImageMagick is installed and available in PATH
$magickPath = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magickPath) {
    Write-Error "ImageMagick is not found. Please ensure ImageMagick 7 is installed and available in PATH."
    exit 1
}

# Check if pdftk is installed and available in PATH
$pdftkPath = Get-Command pdftk -ErrorAction SilentlyContinue
if (-not $pdftkPath) {
    Write-Error "pdftk is not found. Please ensure pdftk is installed and available in PATH."
    exit 1
}

# Create a timestamp for the log file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $ScanPath "integrity_check_failures_$timestamp.log"

# Script header information
$headerInfo = @"
=== Media Integrity Check ===
Date and Time (UTC): 2025-03-26 22:37:22
User: NeoMatrix14241
Scan Path: $ScanPath
Parallel Jobs: $MaxParallelJobs
========================

"@

Write-Host $headerInfo
Add-Content -Path $logFile -Value $headerInfo

# Separate file extensions
$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.tiff", "*.webp", "*.tif")
$pdfExtension = "*.pdf"

# Create synchronized counters
$sync = [System.Collections.Concurrent.ConcurrentDictionary[string,int]]::new()
$sync["total"] = 0
$sync["failed"] = 0

# Create a mutex for logging
$mutex = [System.Threading.Mutex]::new($false, "LoggingMutex")

# Get all files to process
$imageFiles = @()
foreach ($extension in $imageExtensions) {
    $imageFiles += Get-ChildItem -Path $ScanPath -Recurse -File -Filter $extension
}
$pdfFiles = @(Get-ChildItem -Path $ScanPath -Recurse -File -Filter $pdfExtension)

# Process image files in parallel
Write-Host "`nChecking image files..."
$imageFiles | ForEach-Object -ThrottleLimit $MaxParallelJobs -Parallel {
    $currentFile = $_.FullName
    $logFile = $using:logFile
    $sync = $using:sync
    $mutex = $using:mutex
    
    try {
        Write-Host "Checking image: $currentFile" -NoNewline
        
        # Use ImageMagick to check file integrity
        $result = & magick identify -verbose $currentFile 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $sync['failed'] = $sync['failed'] + 1
            
            # Thread-safe logging
            $mutex.WaitOne() | Out-Null
            try {
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): FAILED: $currentFile"
                Add-Content -Path $logFile -Value $logEntry
                Write-Host " - FAILED" -ForegroundColor Red
            }
            finally {
                $mutex.ReleaseMutex()
            }
        } else {
            Write-Host " - OK" -ForegroundColor Green
        }
    }
    catch {
        $sync['failed'] = $sync['failed'] + 1
        
        # Thread-safe logging
        $mutex.WaitOne() | Out-Null
        try {
            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): ERROR: $currentFile - $($_.Exception.Message)"
            Add-Content -Path $logFile -Value $logEntry
            Write-Host " - ERROR" -ForegroundColor Red
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
    finally {
        $sync['total'] = $sync['total'] + 1
    }
}

# Process PDF files in parallel
Write-Host "`nChecking PDF files..."
$pdfFiles | ForEach-Object -ThrottleLimit $MaxParallelJobs -Parallel {
    $currentFile = $_.FullName
    $logFile = $using:logFile
    $sync = $using:sync
    $mutex = $using:mutex
    
    try {
        Write-Host "Checking PDF: $currentFile" -NoNewline
        
        # Use pdftk to check PDF integrity
        $result = & pdftk $currentFile dump_data_utf8 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " - OK" -ForegroundColor Green
        } else {
            $sync['failed'] = $sync['failed'] + 1
            
            # Thread-safe logging
            $mutex.WaitOne() | Out-Null
            try {
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): FAILED: $currentFile"
                Add-Content -Path $logFile -Value $logEntry
                Write-Host " - FAILED" -ForegroundColor Red
            }
            finally {
                $mutex.ReleaseMutex()
            }
        }
    }
    catch {
        $sync['failed'] = $sync['failed'] + 1
        
        # Thread-safe logging
        $mutex.WaitOne() | Out-Null
        try {
            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): ERROR: $currentFile - $($_.Exception.Message)"
            Add-Content -Path $logFile -Value $logEntry
            Write-Host " - ERROR" -ForegroundColor Red
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
    finally {
        $sync['total'] = $sync['total'] + 1
    }
}

# Write summary
$summary = @"

=== Integrity Check Summary ===
Scan Path: $ScanPath
Total files checked: $($sync['total'])
Failed checks: $($sync['failed'])
Failed files are logged in: $logFile
"@

Write-Host $summary
Add-Content -Path $logFile -Value $summary