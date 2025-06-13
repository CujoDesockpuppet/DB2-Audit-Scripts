#!/bin/bash
# Script: db2audit_date_selector.sh
#
# Description:
#   This script allows users to select a range of dates for DB2 audit archive
#   files. It prompts for a start and end date (YYYY-MM-DD), validates the
#   input, and then identifies all audit log files within the specified
#   archive directory that fall within the chosen date range.
#   It's designed to be run by the 'db2<SID>' user.
#
# Usage:
#   db2audit_date_selector.sh <DB_SID>
#   Example: db2audit_date_selector.sh CAP
#           db2audit_date_selector.sh cai
#   The database SID is mandatory and is not case-sensitive.
#
# Author: The Kevin
# Date: June 7, 2025

# --- BEGIN CONFIGURATION ---
# Base directory where DB2 audit files are archived.
# This typically contains subdirectories like /db2/<SID>/AUDIT/audarchive
AUDIT_ARCHIVE_DIR_BASE="/db2"

# Expected date format for user input
DATE_FORMAT_PROMPT="YYYY-MM-DD"

# Directory where the extracted .del files will be written.
# These files will be appended to, not overwritten.
# Make sure this directory is writable by the 'db2<SID>' user.
EXTRACT_OUTPUT_DIR_BASE="/db2" # Base path for your final output

# --- END CONFIGURATION ---


# --- Global Variables for Logging ---
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
LOGDIR="" # This will be set dynamically based on SID
LOGFILE="" # This will be set dynamically based on PID

# --- Determine the best AWK command to use (for AIX compatibility) ---
# Try gawk first, then nawk, then fallback to default awk (which we now know is insufficient)
AWK_CMD=$(command -v gawk || command -v nawk || command -v awk)

# Redirect all output (stdout and stderr) to a temporary log file first
# This ensures that even if final logdir is an issue, we capture initial errors
LOGFILE_TEMP="/tmp/db2audit_selector.$$.log"
exec > "$LOGFILE_TEMP" 2>&1

echo "Script ${SCRIPT_PATH} started at $(date)"
echo "DEBUG: Identified AWK command: ${AWK_CMD}" # <--- NEW DEBUG LINE

# --- Function Definitions ---

# Function to validate date format (YYYY-MM-DD) for AIX
# Returns 0 for valid, 1 for invalid
validate_date_format() {
    local date_str="$1"
    # First, validate the string format using regex
    if [[ "$date_str" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
        local year=${BASH_REMATCH[1]}
        local month=${BASH_REMATCH[2]}
        local day=${BASH_REMATCH[3]}

        echo "DEBUG: validate_date_format received date_str: '$date_str'" >&3
        echo "DEBUG: Extracted year: $year, month: $month, day: $day" >&3

        # Use awk to attempt conversion to epoch and back to validate the date
        # Explicitly set LC_ALL=C for awk to ensure consistent behavior regardless of system locale
        local awk_debug_output=$(LC_ALL=C "$AWK_CMD" -v y="$year" -v m="$month" -v d="$day" 'BEGIN {
            # This ensures input components are always printed
            printf "AWK_DEBUG: Input components: y=%s, m=%s, d=%s\n", y, m, d;
            
            # Construct the string for mktime
            date_for_mktime_str = y " " m " " d " 00 00 00";
            printf "AWK_DEBUG: String passed to mktime: \"%s\"\n", date_for_mktime_str;

            # Attempt to get epoch time
            epoch_time = mktime(date_for_mktime_str);
            
            # Explicitly check mktime return value and print
            if (epoch_time == -1) {
                printf "AWK_DEBUG: mktime() returned -1. This indicates an invalid date or an issue with mktime() itself.\n";
                print "AWK_RESULT: INVALID"; # Explicitly print INVALID
            } else {
                printf "AWK_DEBUG: mktime() result (epoch): %s\n", epoch_time;
                # Convert the epoch time back to impenetrable-MM-DD format
                reformed_date = strftime("%Y-%m-%d", epoch_time);
                printf "AWK_DEBUG: strftime() result (reformed date): %s\n", reformed_date;

                # Compare the original components to the reformed date
                if (reformed_date == (y"-"m"-"d)) {
                    print "AWK_RESULT: VALID"; # Date is genuinely valid
                } else {
                    # Date was "normalized" (e.g., Feb 30th became Mar 02nd)
                    printf "AWK_DEBUG: Date was normalized (original components: %s-%s-%s, reformed: %s). It was invalid.\n", y, m, d, reformed_date;
                    print "AWK_RESULT: INVALID";
                }
            }
        }')
        
        # Always echo the entire awk output to the debug stream
        echo "$awk_debug_output" >&3

        # Extract just the "VALID" or "INVALID" from the awk output
        local awk_validation_result=$(echo "$awk_debug_output" | grep "AWK_RESULT:" | awk '{print $NF}')

        if [[ "$awk_validation_result" == "VALID" ]]; then
            return 0 # Valid format and date
        else
            echo "Error: '$date_str' is not a valid date." >&3 # Redirect error to terminal
            return 1 # Invalid date
        fi
    else
        echo "Error: Date '$date_str' is not in the required format ($DATE_FORMAT_PROMPT)." >&3 # Redirect error to terminal
        return 1 # Invalid format
    fi
}

# Function to validate date range (start date <= end date) for AIX
# Returns 0 for valid, 1 for invalid
validate_date_range() {
    local start_date="$1"
    local end_date="$2"

    # Convert to seconds since epoch for comparison using awk
    # Explicitly set LC_ALL=C for awk
    local start_sec=$(LC_ALL=C "$AWK_CMD" -v date_str="$start_date" 'BEGIN {
        split(date_str, d, "-");
        epoch_val = mktime(d[1] " " d[2] " " d[3] " 00 00 00");
        print epoch_val;
    }')
    local end_sec=$(LC_ALL=C "$AWK_CMD" -v date_str="$end_date" 'BEGIN {
        split(date_str, d, "-");
        epoch_val = mktime(d[1] " " d[2] " " d[3] " 00 00 00");
        print epoch_val;
    }')

    # Check if awk conversion returned -1 (shouldn't happen if validate_date_format passed)
    if [[ "$start_sec" == "-1" || "$end_sec" == "-1" ]]; then
        echo "Internal Error: Date conversion to epoch failed for range check. This should not happen if previous validation passed." >&3
        return 1
    fi

    if (( start_sec > end_sec )); then
        echo "Error: Start date ($start_date) cannot be after end date ($end_date)." >&3 # Redirect error to terminal
        return 1
    else
        return 0
    fi
}

# Function to safely move the log file and print a final message
cleanup_and_exit() {
    local exit_code=$1
    local final_log_path="$LOGDIR/$(basename "$0")_$(date +%Y%m%d_%H%M%S).log"

    echo "Script ${SCRIPT_PATH} completed at $(date)"

    # Attempt to move the temporary log file to its final destination
    if [ -n "$LOGDIR" ] && [ -d "$LOGDIR" ]; then
        mv "$LOGFILE_TEMP" "$final_log_path"
        # Print message to console (using file descriptor 3, which is linked to /dev/tty)
        echo "Log written to $final_log_path" >&3
    else
        # If LOGDIR not set or not a directory, keep log in /tmp and inform user
        echo "Warning: Could not move log to $LOGDIR (directory might not exist or be set)." >&3
        echo "Log remains at $LOGFILE_TEMP" >&3
    fi

    # Close file descriptor 3 before exiting
    exec 3>&-
    exit "$exit_code"
}


# --- Script Execution Begins ---

# Open file descriptor 3 for writing to the terminal (/dev/tty) and reading from it
# This allows prompts to be displayed and input to be read from the user.
exec 3<> /dev/tty

# 1. Validate mandatory SID argument
if [ "$#" -lt 1 ]; then
    echo "No database SID supplied. Usage: $(basename "$0") <DB_SID>" >&3
    echo "Example: $(basename "$0") CAP" >&3
    cleanup_and_exit 1
fi

# Convert SID to uppercase for consistency in paths
CUR_SID=${1^^}

# Set the final LOGDIR now that CUR_SID is known
LOGDIR="${AUDIT_ARCHIVE_DIR_BASE}/${CUR_SID}/AUDIT/log"
# Set the final EXTRACT_OUTPUT_DIR based on SID
FINAL_EXTRACT_DIR="${EXTRACT_OUTPUT_DIR_BASE}/${CUR_SID}/AUDIT/extracted_del"

# Verify LOGDIR exists and is writable (it might be created by audsweep.sh)
if [ ! -d "$LOGDIR" ]; then
    echo "Error: Log directory '$LOGDIR' does not exist." >&3
    echo "Please ensure the path is correct or run audsweep.sh first to create it." >&3
    cleanup_and_exit 10
fi

# 2. Prompt for and validate Start Date
read -p "Enter Start Date ($DATE_FORMAT_PROMPT): " START_DATE <&3 2>&3
while ! validate_date_format "$START_DATE"; do
    read -p "Please re-enter Start Date ($DATE_FORMAT_PROMPT): " START_DATE <&3 2>&3
done

# 3. Prompt for and validate End Date
read -p "Enter End Date ($DATE_FORMAT_PROMPT): " END_DATE <&3 2>&3
while ! validate_date_format "$END_DATE"; do
    read -p "Please re-enter End Date ($DATE_FORMAT_PROMPT): " END_DATE <&3 2>&3
done

# 4. Validate Date Range
while ! validate_date_range "$START_DATE" "$END_DATE"; do
    echo "Please ensure Start Date is not after End Date." >&3
    read -p "Re-enter Start Date ($DATE_FORMAT_PROMPT): " START_DATE <&3 2>&3
    while ! validate_date_format "$START_DATE"; do
        read -p "Please re-enter Start Date ($DATE_FORMAT_PROMPT): " START_DATE <&3 2>&3
    done

    read -p "Re-enter End Date ($DATE_FORMAT_PROMPT): " END_DATE <&3 2>&3
    while ! validate_date_format "$END_DATE"; do
        read -p "Please re-enter End Date ($DATE_FORMAT_PROMPT): " END_DATE <&3 2>&3
    done
done

echo "" >&3
echo "--- Selected Date Range ---" >&3
echo "Start Date: $START_DATE" >&3
echo "End Date:   $END_DATE" >&3
echo "---------------------------" >&3
echo "" >&3

# 5. Identify Audit Archive Directory
AUDIT_ARCHIVE_PATH="${AUDIT_ARCHIVE_DIR_BASE}/${CUR_SID}/AUDIT/audarchive"

if [ ! -d "$AUDIT_ARCHIVE_PATH" ]; then
    echo "Error: DB2 Audit Archive directory '$AUDIT_ARCHIVE_PATH' not found." >&3
    echo "Please ensure the path is correct and archiving has occurred." >&3
    cleanup_and_exit 20
fi

echo "Scanning for DB2 audit files in: $AUDIT_ARCHIVE_PATH"
echo "Matching files for SID: $CUR_SID within date range ($START_DATE to $END_DATE):"
echo "----------------------------------------------------------------------"

FOUND_FILES=()

# Loop through potential audit files (instance and database specific)
for FILE in "${AUDIT_ARCHIVE_PATH}"/db2audit.{instance,db."$CUR_SID"}.log.0.*; do
    # Check if the file exists and is a regular file (handles cases where no files match glob)
    if [ -f "$FILE" ]; then
        # Extract the timestamp part from the filename
        FILENAME=$(basename "$FILE")
        FILE_TIMESTAMP=$(echo "$FILENAME" | awk -F'.' '{print substr($NF, 1, 14)}')

        if [[ -n "$FILE_TIMESTAMP" && "$FILE_TIMESTAMP" =~ ^[0-9]{14}$ ]]; then
            # Extract date part (YYYYMMDD)
            FILE_DATE_YYYYMMDD=${FILE_TIMESTAMP:0:8}
            # Convert to impenetrable-MM-DD format for comparison
            FILE_DATE_FORMATTED="${FILE_DATE_YYYYMMDD:0:4}-${FILE_DATE_YYYYMMDD:4:2}-${FILE_DATE_YYYYMMDD:6:2}"

            # Convert dates to seconds since epoch for numerical comparison using awk
            # Explicitly set LC_ALL=C for awk
            FILE_DATE_SEC=$(LC_ALL=C "$AWK_CMD" -v d="$FILE_DATE_FORMATTED" 'BEGIN { split(d,a,"-"); print mktime(a[1]" "a[2]" "a[3]" 00 00 00") }')
            START_DATE_SEC=$(LC_ALL=C "$AWK_CMD" -v d="$START_DATE" 'BEGIN { split(d,a,"-"); print mktime(a[1]" "a[2]" "a[3]" 00 00 00") }')
            END_DATE_SEC=$(LC_ALL=C "$AWK_CMD" -v d="$END_DATE" 'BEGIN { split(d,a,"-"); print mktime(a[1]" "a[2]" "a[3]" 00 00 00") }')

            # Check if awk conversion failed (mktime returns -1)
            if [[ "$FILE_DATE_SEC" == "-1" || "$START_DATE_SEC" == "-1" || "$END_DATE_SEC" == "-1" ]]; then
                echo "Warning: Could not convert date from filename '$FILE_DATE_FORMATTED' or comparison dates to epoch. Skipping file."
                continue # Skip to next file
            fi

            # Now compare epochs
            if (( FILE_DATE_SEC >= START_DATE_SEC )) && (( FILE_DATE_SEC <= END_DATE_SEC )); then
                FOUND_FILES+=("$FILE")
            fi
        else
            echo "Warning: Could not extract valid timestamp from filename: $FILENAME. Skipping file."
        fi
    fi
done

# 6. Report Found Files and Process Them
if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo "No DB2 audit files found in the specified date range ($START_DATE to $END_DATE)."
else
    echo "Found ${#FOUND_FILES[@]} DB2 audit file(s):"
    for F in "${FOUND_FILES[@]}"; do
        echo "  - $F"
    done

    echo ""
    echo "--- Processing Audit Files (Appending to .del files) ---"

    # Ensure the final output directory exists
    mkdir -p "$FINAL_EXTRACT_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create output directory '$FINAL_EXTRACT_DIR'." >&3
        cleanup_and_exit 30
    fi
    echo "Extracted .del files will be written to: $FINAL_EXTRACT_DIR"

    # Temporary directory to hold extracts from a single file to handle headers
    TEMP_EXTRACT_DIR="/tmp/db2audit_temp_extract.$$"
    mkdir -p "$TEMP_EXTRACT_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create temporary directory '$TEMP_EXTRACT_DIR'." >&3
        cleanup_and_exit 31
    fi

    # Loop through the found files and process them
    for audit_file in "${FOUND_FILES[@]}"; do
        echo "Processing: $audit_file"
        
        # Clean up the temporary extract directory before each new file's extraction
        rm -f "$TEMP_EXTRACT_DIR"/*.del

        # Run db2audit extract for the current file to a temporary location
        # This will create files like audit.del, checking.del etc. in TEMP_EXTRACT_DIR
        db2audit extract delasc from files "$audit_file" to "$TEMP_EXTRACT_DIR"
        if [ $? -ne 0 ]; then
            echo "Warning: 'db2audit extract' failed for file: $audit_file. Skipping this file." >&3
            continue # Move to the next audit file
        fi

        # Iterate through the .del files generated in the temporary directory
        # and append their content (skipping header if file already exists)
        for temp_del_file in "$TEMP_EXTRACT_DIR"/*.del; do
            if [ -f "$temp_del_file" ]; then
                local filename=$(basename "$temp_del_file")
                local final_del_path="${FINAL_EXTRACT_DIR}/${filename}"

                if [ -f "$final_del_path" ]; then
                    # If the final .del file already exists, append content, skipping the header
                    echo "Appending to existing file: $final_del_path"
                    tail -n +2 "$temp_del_file" >> "$final_del_path"
                else
                    # If it's a new .del file type, just copy it over (header included)
                    echo "Creating new file: $final_del_path"
                    cp "$temp_del_file" "$final_del_path"
                fi
            fi
        done
    done

    # Clean up the temporary extract directory for single-file processing
    echo "Cleaning up temporary extract directory: $TEMP_EXTRACT_DIR" >&3
    rm -rf "$TEMP_EXTRACT_DIR"

    echo ""
    echo "All selected audit files have been processed."
    echo "Extracted .del files (appended) are located in: $FINAL_EXTRACT_DIR"
    echo "You can now use these .del files for loading into database tables."
    echo "------------------------------"
fi

cleanup_and_exit 0

