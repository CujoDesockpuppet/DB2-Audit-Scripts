# Script: db2audit_date_selector.ps1
#
# Description:
#   This script allows users to select a range of dates for DB2 audit archive
#   files. It prompts for a start and end date (YYYY-MM-DD), validates the
#   input, and then identifies all audit log files within the specified
#   archive directory that fall within the chosen date range.
#   It's designed to be run by the 'db2<SID>' user.
#
# Usage:
#   .\db2audit_date_selector.ps1 <DB_SID>
#   Example: .\db2audit_date_selector.ps1 CAP
#            .\db2audit_date_selector.ps1 cai
#   The database SID is mandatory and is not case-sensitive.
#
# Author: The Kevin
# Date: June 7, 2025 (Converted to PowerShell: June 12, 2025)

# --- BEGIN CONFIGURATION ---
# Base directory where DB2 audit files are archived.
# This typically contains subdirectories like D:\db2\<SID>\AUDIT\audarchive
# Use Windows path format (backslashes or forward slashes, but backslashes are standard)
$AUDIT_ARCHIVE_DIR_BASE = "C:\db2" # Changed to C:\db2 for Windows example

# Expected date format for user input
$DATE_FORMAT_PROMPT = "YYYY-MM-DD"

# Directory where the extracted .del files will be written.
# These files will be appended to, not overwritten.
# Make sure this directory is writable by the 'db2<SID>' user.
$EXTRACT_OUTPUT_DIR_BASE = "C:\db2" # Base path for your final output

# --- END CONFIGURATION ---

# --- Global Variables for Logging ---
$ScriptPath = $MyInvocation.MyCommand.Definition
$LogDir = "" # This will be set dynamically based on SID
$LogFile = "" # This will be set dynamically based on PID (Process ID)

# Redirect all output (stdout and stderr) to a temporary log file first
# This ensures that even if final logdir is an issue, we capture initial errors
$TempLogFile = "$env:TEMP\db2audit_selector.$PID.log"
Start-Transcript -Path $TempLogFile -Append -Force

Write-Host "Script $ScriptPath started at $(Get-Date)"

# --- Function Definitions ---

# Function to validate date format (YYYY-MM-DD)
# Returns $true for valid, $false for invalid
function Validate-DateFormat {
    param (
        [string]$DateString
    )

    Write-Host "DEBUG: Validate-DateFormat received DateString: '$DateString'"

    if ($DateString -match '^(\d{4})-(\d{2})-(\d{2})$') {
        try {
            $Year = $Matches[1]
            $Month = $Matches[2]
            $Day = $Matches[3]

            Write-Host "DEBUG: Extracted year: $Year, month: $Month, day: $Day"

            # Attempt to create a DateTime object to validate the date components
            $null = [datetime]::ParseExact($DateString, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            Write-Host "DEBUG: Date '$DateString' is valid."
            return $true
        }
        catch {
            Write-Host "Error: '$DateString' is not a valid date. $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Error: Date '$DateString' is not in the required format ($DATE_FORMAT_PROMPT)." -ForegroundColor Red
        return $false
    }
}

# Function to validate date range (start date <= end date)
# Returns $true for valid, $false for invalid
function Validate-DateRange {
    param (
        [string]$StartDate,
        [string]$EndDate
    )

    try {
        $StartDateObj = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $EndDateObj = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)

        if ($StartDateObj -gt $EndDateObj) {
            Write-Host "Error: Start date ($StartDate) cannot be after end date ($EndDate)." -ForegroundColor Red
            return $false
        } else {
            return $true
        }
    }
    catch {
        Write-Host "Internal Error: Date conversion for range check failed. This should not happen if previous validation passed. $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to safely move the log file and print a final message
function Cleanup-And-Exit {
    param (
        [int]$ExitCode
    )

    Stop-Transcript

    Write-Host "Script $ScriptPath completed at $(Get-Date)"

    $FinalLogPath = Join-Path $LogDir ( "db2audit_selector_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log" )

    # Attempt to move the temporary log file to its final destination
    if ($LogDir -ne "" -and (Test-Path $LogDir -PathType Container)) {
        try {
            Move-Item -Path $TempLogFile -Destination $FinalLogPath -Force
            Write-Host "Log written to $FinalLogPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Warning: Could not move log to $LogDir. $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Log remains at $TempLogFile" -ForegroundColor Yellow
        }
    } else {
        # If LOGDIR not set or not a directory, keep log in %TEMP% and inform user
        Write-Host "Warning: Could not move log to $LogDir (directory might not exist or be set)." -ForegroundColor Yellow
        Write-Host "Log remains at $TempLogFile" -ForegroundColor Yellow
    }

    exit $ExitCode
}


# --- Script Execution Begins ---

# 1. Validate mandatory SID argument
if ($Args.Count -lt 1) {
    Write-Host "No database SID supplied. Usage: $($MyInvocation.MyCommand.Name) <DB_SID>" -ForegroundColor Red
    Write-Host "Example: $($MyInvocation.MyCommand.Name) CAP" -ForegroundColor Red
    Cleanup-And-Exit 1
}

# Convert SID to uppercase for consistency in paths
$CurrentSID = $Args[0].ToUpper()

# Set the final LOGDIR now that CurrentSID is known
$LogDir = Join-Path $AUDIT_ARCHIVE_DIR_BASE $CurrentSID "AUDIT" "log"
# Set the final EXTRACT_OUTPUT_DIR based on SID
$FinalExtractDir = Join-Path $EXTRACT_OUTPUT_DIR_BASE $CurrentSID "AUDIT" "extracted_del"

# Verify LOGDIR exists and is writable
if (-not (Test-Path $LogDir -PathType Container)) {
    Write-Host "Error: Log directory '$LogDir' does not exist." -ForegroundColor Red
    Write-Host "Please ensure the path is correct or ensure it's created." -ForegroundColor Red
    Cleanup-And-Exit 10
}

# 2. Prompt for and validate Start Date
do {
    $StartDate = Read-Host "Enter Start Date ($DATE_FORMAT_PROMPT)"
} while (-not (Validate-DateFormat $StartDate))

# 3. Prompt for and validate End Date
do {
    $EndDate = Read-Host "Enter End Date ($DATE_FORMAT_PROMPT)"
} while (-not (Validate-DateFormat $EndDate))

# 4. Validate Date Range
while (-not (Validate-DateRange $StartDate $EndDate)) {
    Write-Host "Please ensure Start Date is not after End Date." -ForegroundColor Red
    do {
        $StartDate = Read-Host "Re-enter Start Date ($DATE_FORMAT_PROMPT)"
    } while (-not (Validate-DateFormat $StartDate))

    do {
        $EndDate = Read-Host "Re-enter End Date ($DATE_FORMAT_PROMPT)"
    } while (-not (Validate-DateFormat $EndDate))
}

Write-Host ""
Write-Host "--- Selected Date Range ---"
Write-Host "Start Date: $StartDate"
Write-Host "End Date:   $EndDate"
Write-Host "---------------------------"
Write-Host ""

# 5. Identify Audit Archive Directory
$AuditArchivePath = Join-Path $AUDIT_ARCHIVE_DIR_BASE $CurrentSID "AUDIT" "audarchive"

if (-not (Test-Path $AuditArchivePath -PathType Container)) {
    Write-Host "Error: DB2 Audit Archive directory '$AuditArchivePath' not found." -ForegroundColor Red
    Write-Host "Please ensure the path is correct and archiving has occurred." -ForegroundColor Red
    Cleanup-And-Exit 20
}

Write-Host "Scanning for DB2 audit files in: $AuditArchivePath"
Write-Host "Matching files for SID: $CurrentSID within date range ($StartDate to $EndDate):"
Write-Host "----------------------------------------------------------------------"

$FoundFiles = @()

# Loop through potential audit files (instance and database specific)
# Using Get-ChildItem with -Filter and -Recurse to find files matching patterns
# Note: The original script used `db2audit.{instance,db."$CUR_SID"}.log.0.*` which is tricky.
# We'll adapt to a more standard Windows file naming, assuming the SID is embedded.
# Example: db2audit.instance.log.0.20250610120000 or db2audit.db.CAP.log.0.20250610120000
$AuditFilePatterns = @(
    "db2audit.instance.log.0.*",
    "db2audit.db.$CurrentSID.log.0.*"
)

foreach ($Pattern in $AuditFilePatterns) {
    Get-ChildItem -Path $AuditArchivePath -Filter $Pattern | ForEach-Object {
        $File = $_.FullName
        $FileName = $_.Name

        # Extract the timestamp part from the filename
        # Example: db2audit.instance.log.0.20250610120000 -> 20250610120000
        if ($FileName -match '\.0\.(\d{14})$') {
            $FileTimestamp = $Matches[1]

            if ($FileTimestamp -and $FileTimestamp.Length -eq 14) {
                # Extract date part (YYYYMMDD)
                $FileDateYYYYMMDD = $FileTimestamp.Substring(0, 8)
                # Convert to YYYY-MM-DD format for comparison
                $FileDateFormatted = "$($FileDateYYYYMMDD.Substring(0,4))-$($FileDateYYYYMMDD.Substring(4,2))-$($FileDateYYYYMMDD.Substring(6,2))"

                try {
                    $FileDateObj = [datetime]::ParseExact($FileDateFormatted, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    $StartDateObj = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    $EndDateObj = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)

                    # Compare dates
                    if ($FileDateObj -ge $StartDateObj -and $FileDateObj -le $EndDateObj) {
                        $FoundFiles += $File
                    }
                }
                catch {
                    Write-Warning "Could not parse date from filename '$FileName'. Skipping file. Error: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Could not extract valid timestamp from filename: $FileName. Skipping file."
            }
        } else {
            Write-Warning "Filename '$FileName' does not match expected pattern for timestamp extraction. Skipping file."
        }
    }
}

# 6. Report Found Files and Process Them
if ($FoundFiles.Count -eq 0) {
    Write-Host "No DB2 audit files found in the specified date range ($StartDate to $EndDate)."
} else {
    Write-Host "Found $($FoundFiles.Count) DB2 audit file(s):"
    foreach ($File in $FoundFiles) {
        Write-Host "  - $File"
    }

    Write-Host ""
    Write-Host "--- Processing Audit Files (Appending to .del files) ---"

    # Ensure the final output directory exists
    if (-not (Test-Path $FinalExtractDir -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $FinalExtractDir | Out-Null
        }
        catch {
            Write-Host "Error: Failed to create output directory '$FinalExtractDir'. $($_.Exception.Message)" -ForegroundColor Red
            Cleanup-And-Exit 30
        }
    }
    Write-Host "Extracted .del files will be written to: $FinalExtractDir"

    # Temporary directory to hold extracts from a single file to handle headers
    $TempExtractDir = "$env:TEMP\db2audit_temp_extract.$PID"
    if (-not (Test-Path $TempExtractDir -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $TempExtractDir | Out-Null
        }
        catch {
            Write-Host "Error: Failed to create temporary directory '$TempExtractDir'. $($_.Exception.Message)" -ForegroundColor Red
            Cleanup-And-Exit 31
        }
    }

    # Loop through the found files and process them
    foreach ($AuditFile in $FoundFiles) {
        Write-Host "Processing: $AuditFile"

        # Clean up the temporary extract directory before each new file's extraction
        Remove-Item -Path (Join-Path $TempExtractDir "*.del") -ErrorAction SilentlyContinue

        # Run db2audit extract for the current file to a temporary location
        # This will create files like audit.del, checking.del etc. in TEMP_EXTRACT_DIR
        # You need to ensure the 'db2audit' command is in your system's PATH
        # or provide the full path to it (e.g., C:\Program Files\IBM\SQLLIB\BIN\db2audit.exe)
        try {
            db2audit extract delasc from files "$AuditFile" to "$TempExtractDir" 2>&1 | Write-Host
        }
        catch {
            Write-Host "Warning: 'db2audit extract' failed for file: $AuditFile. Skipping this file. Error: $($_.Exception.Message)" -ForegroundColor Yellow
            continue # Move to the next audit file
        }

        # Iterate through the .del files generated in the temporary directory
        # and append their content (skipping header if file already exists)
        Get-ChildItem -Path $TempExtractDir -Filter "*.del" | ForEach-Object {
            $TempDelFile = $_.FullName
            $Filename = $_.Name
            $FinalDelPath = Join-Path $FinalExtractDir $Filename

            if (Test-Path $FinalDelPath) {
                # If the final .del file already exists, append content, skipping the header
                Write-Host "Appending to existing file: $FinalDelPath"
                # Get-Content -Raw reads the entire file as a single string, then split and skip first line
                (Get-Content -Path $TempDelFile | Select-Object -Skip 1) | Add-Content -Path $FinalDelPath
            } else {
                # If it's a new .del file type, just copy it over (header included)
                Write-Host "Creating new file: $FinalDelPath"
                Copy-Item -Path $TempDelFile -Destination $FinalDelPath -Force
            }
        }
    }

    # Clean up the temporary extract directory for single-file processing
    Write-Host "Cleaning up temporary extract directory: $TempExtractDir"
    Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "All selected audit files have been processed." -ForegroundColor Green
    Write-Host "Extracted .del files (appended) are located in: $FinalExtractDir" -ForegroundColor Green
    Write-Host "You can now use these .del files for loading into database tables." -ForegroundColor Green
    Write-Host "------------------------------"
}

Cleanup-And-Exit 0

*************

The Bash script you provided is designed for a Unix-like environment (Linux, AIX) and uses several features that don't directly translate to Windows, such as /dev/tty, awk, grep, mv, rm, tail, and specific path conventions (/db2).

Converting this to a batch script (.bat or .cmd) for Windows would be extremely complex due to the differences in shell features, command-line utilities, and date manipulation. PowerShell is a much more suitable environment for this kind of conversion, as it offers more robust scripting capabilities and better equivalents for Unix commands.

Below is a PowerShell script that replicates the functionality of your Bash script for a Windows environment.

PowerShell

# Script: db2audit_date_selector.ps1
#
# Description:
#   This script allows users to select a range of dates for DB2 audit archive
#   files. It prompts for a start and end date (YYYY-MM-DD), validates the
#   input, and then identifies all audit log files within the specified
#   archive directory that fall within the chosen date range.
#   It's designed to be run by the 'db2<SID>' user.
#
# Usage:
#   .\db2audit_date_selector.ps1 <DB_SID>
#   Example: .\db2audit_date_selector.ps1 CAP
#            .\db2audit_date_selector.ps1 cai
#   The database SID is mandatory and is not case-sensitive.
#
# Author: The Kevin
# Date: June 7, 2025 (Converted to PowerShell: June 12, 2025)

# --- BEGIN CONFIGURATION ---
# Base directory where DB2 audit files are archived.
# This typically contains subdirectories like D:\db2\<SID>\AUDIT\audarchive
# Use Windows path format (backslashes or forward slashes, but backslashes are standard)
$AUDIT_ARCHIVE_DIR_BASE = "C:\db2" # Changed to C:\db2 for Windows example

# Expected date format for user input
$DATE_FORMAT_PROMPT = "YYYY-MM-DD"

# Directory where the extracted .del files will be written.
# These files will be appended to, not overwritten.
# Make sure this directory is writable by the 'db2<SID>' user.
$EXTRACT_OUTPUT_DIR_BASE = "C:\db2" # Base path for your final output

# --- END CONFIGURATION ---

# --- Global Variables for Logging ---
$ScriptPath = $MyInvocation.MyCommand.Definition
$LogDir = "" # This will be set dynamically based on SID
$LogFile = "" # This will be set dynamically based on PID (Process ID)

# Redirect all output (stdout and stderr) to a temporary log file first
# This ensures that even if final logdir is an issue, we capture initial errors
$TempLogFile = "$env:TEMP\db2audit_selector.$PID.log"
Start-Transcript -Path $TempLogFile -Append -Force

Write-Host "Script $ScriptPath started at $(Get-Date)"

# --- Function Definitions ---

# Function to validate date format (YYYY-MM-DD)
# Returns $true for valid, $false for invalid
function Validate-DateFormat {
    param (
        [string]$DateString
    )

    Write-Host "DEBUG: Validate-DateFormat received DateString: '$DateString'"

    if ($DateString -match '^(\d{4})-(\d{2})-(\d{2})$') {
        try {
            $Year = $Matches[1]
            $Month = $Matches[2]
            $Day = $Matches[3]

            Write-Host "DEBUG: Extracted year: $Year, month: $Month, day: $Day"

            # Attempt to create a DateTime object to validate the date components
            $null = [datetime]::ParseExact($DateString, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            Write-Host "DEBUG: Date '$DateString' is valid."
            return $true
        }
        catch {
            Write-Host "Error: '$DateString' is not a valid date. $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Error: Date '$DateString' is not in the required format ($DATE_FORMAT_PROMPT)." -ForegroundColor Red
        return $false
    }
}

# Function to validate date range (start date <= end date)
# Returns $true for valid, $false for invalid
function Validate-DateRange {
    param (
        [string]$StartDate,
        [string]$EndDate
    )

    try {
        $StartDateObj = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $EndDateObj = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)

        if ($StartDateObj -gt $EndDateObj) {
            Write-Host "Error: Start date ($StartDate) cannot be after end date ($EndDate)." -ForegroundColor Red
            return $false
        } else {
            return $true
        }
    }
    catch {
        Write-Host "Internal Error: Date conversion for range check failed. This should not happen if previous validation passed. $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to safely move the log file and print a final message
function Cleanup-And-Exit {
    param (
        [int]$ExitCode
    )

    Stop-Transcript

    Write-Host "Script $ScriptPath completed at $(Get-Date)"

    $FinalLogPath = Join-Path $LogDir ( "db2audit_selector_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log" )

    # Attempt to move the temporary log file to its final destination
    if ($LogDir -ne "" -and (Test-Path $LogDir -PathType Container)) {
        try {
            Move-Item -Path $TempLogFile -Destination $FinalLogPath -Force
            Write-Host "Log written to $FinalLogPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Warning: Could not move log to $LogDir. $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "Log remains at $TempLogFile" -ForegroundColor Yellow
        }
    } else {
        # If LOGDIR not set or not a directory, keep log in %TEMP% and inform user
        Write-Host "Warning: Could not move log to $LogDir (directory might not exist or be set)." -ForegroundColor Yellow
        Write-Host "Log remains at $TempLogFile" -ForegroundColor Yellow
    }

    exit $ExitCode
}


# --- Script Execution Begins ---

# 1. Validate mandatory SID argument
if ($Args.Count -lt 1) {
    Write-Host "No database SID supplied. Usage: $($MyInvocation.MyCommand.Name) <DB_SID>" -ForegroundColor Red
    Write-Host "Example: $($MyInvocation.MyCommand.Name) CAP" -ForegroundColor Red
    Cleanup-And-Exit 1
}

# Convert SID to uppercase for consistency in paths
$CurrentSID = $Args[0].ToUpper()

# Set the final LOGDIR now that CurrentSID is known
$LogDir = Join-Path $AUDIT_ARCHIVE_DIR_BASE $CurrentSID "AUDIT" "log"
# Set the final EXTRACT_OUTPUT_DIR based on SID
$FinalExtractDir = Join-Path $EXTRACT_OUTPUT_DIR_BASE $CurrentSID "AUDIT" "extracted_del"

# Verify LOGDIR exists and is writable
if (-not (Test-Path $LogDir -PathType Container)) {
    Write-Host "Error: Log directory '$LogDir' does not exist." -ForegroundColor Red
    Write-Host "Please ensure the path is correct or ensure it's created." -ForegroundColor Red
    Cleanup-And-Exit 10
}

# 2. Prompt for and validate Start Date
do {
    $StartDate = Read-Host "Enter Start Date ($DATE_FORMAT_PROMPT)"
} while (-not (Validate-DateFormat $StartDate))

# 3. Prompt for and validate End Date
do {
    $EndDate = Read-Host "Enter End Date ($DATE_FORMAT_PROMPT)"
} while (-not (Validate-DateFormat $EndDate))

# 4. Validate Date Range
while (-not (Validate-DateRange $StartDate $EndDate)) {
    Write-Host "Please ensure Start Date is not after End Date." -ForegroundColor Red
    do {
        $StartDate = Read-Host "Re-enter Start Date ($DATE_FORMAT_PROMPT)"
    } while (-not (Validate-DateFormat $StartDate))

    do {
        $EndDate = Read-Host "Re-enter End Date ($DATE_FORMAT_PROMPT)"
    } while (-not (Validate-DateFormat $EndDate))
}

Write-Host ""
Write-Host "--- Selected Date Range ---"
Write-Host "Start Date: $StartDate"
Write-Host "End Date:   $EndDate"
Write-Host "---------------------------"
Write-Host ""

# 5. Identify Audit Archive Directory
$AuditArchivePath = Join-Path $AUDIT_ARCHIVE_DIR_BASE $CurrentSID "AUDIT" "audarchive"

if (-not (Test-Path $AuditArchivePath -PathType Container)) {
    Write-Host "Error: DB2 Audit Archive directory '$AuditArchivePath' not found." -ForegroundColor Red
    Write-Host "Please ensure the path is correct and archiving has occurred." -ForegroundColor Red
    Cleanup-And-Exit 20
}

Write-Host "Scanning for DB2 audit files in: $AuditArchivePath"
Write-Host "Matching files for SID: $CurrentSID within date range ($StartDate to $EndDate):"
Write-Host "----------------------------------------------------------------------"

$FoundFiles = @()

# Loop through potential audit files (instance and database specific)
# Using Get-ChildItem with -Filter and -Recurse to find files matching patterns
# Note: The original script used `db2audit.{instance,db."$CUR_SID"}.log.0.*` which is tricky.
# We'll adapt to a more standard Windows file naming, assuming the SID is embedded.
# Example: db2audit.instance.log.0.20250610120000 or db2audit.db.CAP.log.0.20250610120000
$AuditFilePatterns = @(
    "db2audit.instance.log.0.*",
    "db2audit.db.$CurrentSID.log.0.*"
)

foreach ($Pattern in $AuditFilePatterns) {
    Get-ChildItem -Path $AuditArchivePath -Filter $Pattern | ForEach-Object {
        $File = $_.FullName
        $FileName = $_.Name

        # Extract the timestamp part from the filename
        # Example: db2audit.instance.log.0.20250610120000 -> 20250610120000
        if ($FileName -match '\.0\.(\d{14})$') {
            $FileTimestamp = $Matches[1]

            if ($FileTimestamp -and $FileTimestamp.Length -eq 14) {
                # Extract date part (YYYYMMDD)
                $FileDateYYYYMMDD = $FileTimestamp.Substring(0, 8)
                # Convert to YYYY-MM-DD format for comparison
                $FileDateFormatted = "$($FileDateYYYYMMDD.Substring(0,4))-$($FileDateYYYYMMDD.Substring(4,2))-$($FileDateYYYYMMDD.Substring(6,2))"

                try {
                    $FileDateObj = [datetime]::ParseExact($FileDateFormatted, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    $StartDateObj = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                    $EndDateObj = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)

                    # Compare dates
                    if ($FileDateObj -ge $StartDateObj -and $FileDateObj -le $EndDateObj) {
                        $FoundFiles += $File
                    }
                }
                catch {
                    Write-Warning "Could not parse date from filename '$FileName'. Skipping file. Error: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Could not extract valid timestamp from filename: $FileName. Skipping file."
            }
        } else {
            Write-Warning "Filename '$FileName' does not match expected pattern for timestamp extraction. Skipping file."
        }
    }
}

# 6. Report Found Files and Process Them
if ($FoundFiles.Count -eq 0) {
    Write-Host "No DB2 audit files found in the specified date range ($StartDate to $EndDate)."
} else {
    Write-Host "Found $($FoundFiles.Count) DB2 audit file(s):"
    foreach ($File in $FoundFiles) {
        Write-Host "  - $File"
    }

    Write-Host ""
    Write-Host "--- Processing Audit Files (Appending to .del files) ---"

    # Ensure the final output directory exists
    if (-not (Test-Path $FinalExtractDir -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $FinalExtractDir | Out-Null
        }
        catch {
            Write-Host "Error: Failed to create output directory '$FinalExtractDir'. $($_.Exception.Message)" -ForegroundColor Red
            Cleanup-And-Exit 30
        }
    }
    Write-Host "Extracted .del files will be written to: $FinalExtractDir"

    # Temporary directory to hold extracts from a single file to handle headers
    $TempExtractDir = "$env:TEMP\db2audit_temp_extract.$PID"
    if (-not (Test-Path $TempExtractDir -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $TempExtractDir | Out-Null
        }
        catch {
            Write-Host "Error: Failed to create temporary directory '$TempExtractDir'. $($_.Exception.Message)" -ForegroundColor Red
            Cleanup-And-Exit 31
        }
    }

    # Loop through the found files and process them
    foreach ($AuditFile in $FoundFiles) {
        Write-Host "Processing: $AuditFile"

        # Clean up the temporary extract directory before each new file's extraction
        Remove-Item -Path (Join-Path $TempExtractDir "*.del") -ErrorAction SilentlyContinue

        # Run db2audit extract for the current file to a temporary location
        # This will create files like audit.del, checking.del etc. in TEMP_EXTRACT_DIR
        # You need to ensure the 'db2audit' command is in your system's PATH
        # or provide the full path to it (e.g., C:\Program Files\IBM\SQLLIB\BIN\db2audit.exe)
        try {
            db2audit extract delasc from files "$AuditFile" to "$TempExtractDir" 2>&1 | Write-Host
        }
        catch {
            Write-Host "Warning: 'db2audit extract' failed for file: $AuditFile. Skipping this file. Error: $($_.Exception.Message)" -ForegroundColor Yellow
            continue # Move to the next audit file
        }

        # Iterate through the .del files generated in the temporary directory
        # and append their content (skipping header if file already exists)
        Get-ChildItem -Path $TempExtractDir -Filter "*.del" | ForEach-Object {
            $TempDelFile = $_.FullName
            $Filename = $_.Name
            $FinalDelPath = Join-Path $FinalExtractDir $Filename

            if (Test-Path $FinalDelPath) {
                # If the final .del file already exists, append content, skipping the header
                Write-Host "Appending to existing file: $FinalDelPath"
                # Get-Content -Raw reads the entire file as a single string, then split and skip first line
                (Get-Content -Path $TempDelFile | Select-Object -Skip 1) | Add-Content -Path $FinalDelPath
            } else {
                # If it's a new .del file type, just copy it over (header included)
                Write-Host "Creating new file: $FinalDelPath"
                Copy-Item -Path $TempDelFile -Destination $FinalDelPath -Force
            }
        }
    }

    # Clean up the temporary extract directory for single-file processing
    Write-Host "Cleaning up temporary extract directory: $TempExtractDir"
    Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "All selected audit files have been processed." -ForegroundColor Green
    Write-Host "Extracted .del files (appended) are located in: $FinalExtractDir" -ForegroundColor Green
    Write-Host "You can now use these .del files for loading into database tables." -ForegroundColor Green
    Write-Host "------------------------------"
}
