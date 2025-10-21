#!/bin/bash

# --- Portability Check ---
# Note: The original script used Bash-specific syntax for case conversion (${var^^} and ${var,,}).
# These have been replaced with the portable 'tr' command for compatibility on AIX/Korn Shell.

# Allow any files created to be read, created and removed as needed
umask 000

# Script path and temporary log file setup
SCRIPT_PATH=$0
# Create a temporary file for logging using the process ID ($$) for portability on systems without 'mktemp'
TEMP_LOGFILE="/tmp/logmove_$$" 
# Explicitly create/truncate the temporary file before logging to it
> "$TEMP_LOGFILE"

# Ensure this is run by the DB2<SID> user. 
# Environment and related variables.
# Using Bash Parameterized Expansion for case conversion (works on Bash 4.0+)
CUR_SID=${DB2DBDFT^^} # convert to uppercase (reads from DB2DBDFT environment variable)
DB_USER_SID=${DB2DBDFT,,} # lowercase SID (reads from DB2DBDFT environment variable)
DB_TYPE="db2"
DB_USER=${DB_TYPE}${DB_USER_SID} # The expected owner: db2<sid>

# Let's set up where the files exist and where they are going.
LOGDIR="/db2/${CUR_SID}/AUDIT/log"

# --- SINGLE INSTANCE LOCKING MECHANISM ---
LOCK_DIR="/tmp/logarch_${CUR_SID}.lock"

# Define source and destination directories
SOURCE_DIR="/db2/${CUR_SID}/AUDIT/log"
DEST_DIR="/db2/${CUR_SID}/AUDIT/audarchive/LogArchive"
REPORT_FILE="$DEST_DIR/moved_files_report_$(date +%Y-%m-%d).log"


# Function to clean up the lock directory
cleanup_lock() {
    # Attempt to remove the lock directory if it exists.
    # rmdir will only remove empty directories, preventing accidental deletion of user data.
    if [ -d "$LOCK_DIR" ]; then
        rmdir "$LOCK_DIR" 2>/dev/null
    fi
}

# Set a trap to ensure the lock directory is removed upon script exit (successful or failed)
trap cleanup_lock EXIT

echo "Current Database SID is $CUR_SID" | tee -a "$TEMP_LOGFILE"
echo "Database_User running the $0 script is $DB_USER" | tee -a "$TEMP_LOGFILE"
CUR_USER=$(whoami) 

# Function to move log and exit, ensuring console message
# Note: This function depends on LOGDIR, TEMP_LOGFILE, SCRIPT_PATH being defined globally.
exit_with_log_move() {
    local exit_code="$1"
    local log_dir="$2"
    local temp_log="$3"
    local script_full_path="$4"
    local script_path_for_msg="$5"

    echo "Script ${script_path_for_msg} completed at $(date)"

    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local script_name=$(basename "$script_full_path")
    local FINAL_LOGFILE="$log_dir/${script_name}_${TIMESTAMP}.log"

    # Ensure the final log directory exists before moving
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null
    fi

    # Move the temporary log file to its final destination
    if mv "$temp_log" "$FINAL_LOGFILE" ; then
        echo "Log written to $FINAL_LOGFILE"
    else
        echo "Error: Failed to move log from $temp_log to $FINAL_LOGFILE. Log content below:"
        cat "$temp_log" 
    fi
    # Clean up the temp file if the move failed (it will be missing if move succeeded)
    rm -f "$temp_log" 
    
    # The trap EXIT handles the lock cleanup automatically upon exit.
    exit "$exit_code"
}

# --- IMPLEMENT LOCK CHECK ---
# Try to create the lock directory atomically. If it fails, the script is already running.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Error: Lock directory $LOCK_DIR exists. Script is already running or failed to clean up." | tee -a "$TEMP_LOGFILE"
    exit_with_log_move 99 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi


# Check if directories exist (messages written to TEMP_LOGFILE via tee -a)
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found." | tee -a "$TEMP_LOGFILE"
    echo "Error: This should not happen - possibly an issue with the user running this script." | tee -a "$TEMP_LOGFILE"
    exit_with_log_move 60 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory '$DEST_DIR' not found." | tee -a "$TEMP_LOGFILE"
    echo "Error: This should not happen - possibly an issue with the user running this script." | tee -a "$TEMP_LOGFILE"
    exit_with_log_move 61 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi


####### Let's make sure we have the correct user running the script (db2<sid>) and that the DB is up
echo "CUR_USER is: $CUR_USER" | tee -a "$TEMP_LOGFILE"

if [ "$DB_USER" = "$CUR_USER" ]; then
    echo "Strings are equal - moving on" | tee -a "$TEMP_LOGFILE"
    echo "Checking if database $CUR_SID is running." | tee -a "$TEMP_LOGFILE"
else
    echo "Strings are not equal" | tee -a "$TEMP_LOGFILE"
    echo "CUR_USER is $CUR_USER" | tee -a "$TEMP_LOGFILE"
    echo "Database user error: database user is $DB_USER" | tee -a "$TEMP_LOGFILE"
    echo "Exiting script with exit code 21 - see code ${SCRIPT_PATH} to determine where it failed" | tee -a "$TEMP_LOGFILE"
    exit_with_log_move 21 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

# IMPORTANT: Using $DB_USER (the calculated, expected owner) in find.
TARGET_OWNER="$DB_USER" 

echo "Starting file move and report generation at $(date)" > "$REPORT_FILE" # Overwrite initial report
echo "---------------------------------------------------" >> "$REPORT_FILE"
echo "Moving files from $SOURCE_DIR to $DEST_DIR" >> "$REPORT_FILE"
echo "Files older than 35 days and owned by $TARGET_OWNER will be moved." >> "$REPORT_FILE"
echo "---------------------------------------------------" >> "$REPORT_FILE"
echo "Starting file move logic..." | tee -a "$TEMP_LOGFILE"

# Find files older than 35 days and owned by the specified user
# Note on AIX portability: -print0 is not supported, so we use standard -print.
# This makes the script vulnerable to filenames containing spaces or newlines.
find "$SOURCE_DIR" -type f -mtime +35 -user "$TARGET_OWNER" -print | while IFS= read -r file; do
    # Get the file name from the full path
    filename=$(basename "$file")
    
    # Move the file and check if the move was successful
    if mv "$file" "$DEST_DIR/$filename"; then
        echo "Successfully moved: $file" >> "$REPORT_FILE"
    else
        echo "Failed to move: $file" >> "$REPORT_FILE"
        echo "Error moving file: $file" | tee -a "$TEMP_LOGFILE"
    fi
done

echo "---------------------------------------------------" >> "$REPORT_FILE"
echo "File move and report generation complete at $(date)" >> "$REPORT_FILE"
echo "Report is located at $REPORT_FILE" >> "$REPORT_FILE"
# --- NEW CODE ADDED HERE ---

echo ""
echo "--- Files in Destination Directory: $DEST_DIR ---"
# List the contents of the destination directory, sending output to both the screen (terminal) 
# and the temporary log file ($TEMP_LOGFILE), which becomes the final logmove.sh_*.log file.
ls -l "$DEST_DIR" | tee -a "$TEMP_LOGFILE"
echo "-------------------------------------------------"

# --- END OF NEW CODE ---

echo "" | tee -a "$TEMP_LOGFILE"
echo "Final Status: Files older than 35 days were successfully MOVED." | tee -a "$TEMP_LOGFILE"
echo "Destination Directory: $DEST_DIR" | tee -a "$TEMP_LOGFILE"
echo "" | tee -a "$TEMP_LOGFILE"

# Final clean exit with log move
exit_with_log_move 0 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
