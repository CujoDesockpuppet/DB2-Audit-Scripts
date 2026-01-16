#!/bin/bash

# --- Configuration ---
# DB2 Database Connection Details
DB_NAME="$DB2DBDFT"
#DB_USER="your_db2_username"
#DB_PASSWORD="your_db2_password" # Be cautious with storing passwords directly in scripts. Consider secure alternatives.

# Base directory where archive files are stored.
# The ARCHIVE_FILE in your DB should be relative to this path.
ARCHIVE_BASE_DIR="/db2/$DB2DBDFT/AUDIT/audarchive/Archiveprocessed"

# Log file for output
LOG_FILE="/db2/$DB2DBDFT/AUDIT/log/checksum_audit_$(date +%Y%m%d_%H%M%S).log"

# Temporary file prefix for database output
# Using $$ (process ID) and date for uniqueness, as mktemp is not available on AIX
TMP_DB_OUTPUT_PREFIX="/tmp/db2_audit_data_$$"


# --- Functions ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

alert_message() {
    echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1" | tee -a "$LOG_FILE"
}

# Function to connect to DB2 and fetch data
get_db_archive_data() {
log_message "Attempting to connect to DB2 database: $DB_NAME"
   # log_message "Attempting to connect to DB2 database: $DB_NAME as user $DB_USER"

    # Generate a unique temporary file name
    # Using date and process ID for uniqueness since mktemp is not available
    local TEMP_FILE="${TMP_DB_OUTPUT_PREFIX}_$(date +%s%N)" # %N for nanoseconds, if available, otherwise just %s
    if [[ "$?" -ne 0 ]]; then
        # Fallback if %N is not supported by AIX date
        TEMP_FILE="${TMP_DB_OUTPUT_PREFIX}_$(date +%s)"
    fi

    # Ensure the directory for the temp file exists, though /tmp usually does
    if [ ! -d "/tmp" ]; then
        alert_message "Temporary directory /tmp does not exist. Cannot create temp file."
        return 1
    fi
    
    # Try to connect to DB2
    # db2 "connect to ${DB_NAME} user ${DB_USER} using ${DB_PASSWORD}" > /dev/null 2>&1
    db2 "connect to ${DB_NAME}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        alert_message "Failed to connect to DB2 database. Please check credentials and connectivity."
        return 1
    fi
    log_message "Successfully connected to DB2."

    # Fetch ARCHIVE_FILE and CHECKSUM.
    # Note: `sed 's/ //g'` removes ALL spaces, which is critical for the later parsing.
    # Ensure ARCHIVE_FILE names in your DB don't contain spaces if this is problematic.
    db2 -x "SELECT ARCHIVE_FILE, CHECKSUM FROM audit.archivelogging" | sed 's/ //g' > "$TEMP_FILE"

    # Disconnect from DB2
    db2 "connect reset" > /dev/null 2>&1
    db2 terminate > /dev/null 2>&1

    # Check if the temporary file contains data
    if [ ! -s "$TEMP_FILE" ]; then
        alert_message "No data retrieved from audit.archivelogging or query failed."
        rm -f "$TEMP_FILE" # Clean up empty/failed temp file
        return 1
    fi
    
    # Return the path to the temporary file
    echo "$TEMP_FILE"
    return 0
}

# --- Main Script ---

log_message "Starting DB2 Checksum Audit Script..."
log_message "Log file: $LOG_FILE"
log_message "Archive Base Directory: $ARCHIVE_BASE_DIR"

# Ensure ARCHIVE_BASE_DIR ends with a slash for consistent path concatenation
if [[ "${ARCHIVE_BASE_DIR}" != */ ]]; then
    ARCHIVE_BASE_DIR="${ARCHIVE_BASE_DIR}/"
fi

DB_DATA_FILE=$(get_db_archive_data)

# Trap to ensure temporary file is cleaned up on script exit (success or failure)
# This uses a function `cleanup_temp_file` to handle removal
cleanup_temp_file() {
    if [ -n "$DB_DATA_FILE" ] && [ -f "$DB_DATA_FILE" ]; then
        rm -f "$DB_DATA_FILE"
        log_message "Cleaned up temporary file: $DB_DATA_FILE"
    fi
}
trap cleanup_temp_file EXIT # Execute cleanup_temp_file on script exit

if [ $? -ne 0 ] || [ -z "$DB_DATA_FILE" ]; then
    alert_message "Aborting script due to database connection or data retrieval issues."
    exit 1
fi

MISMATHCED_COUNT=0
MISSING_COUNT=0

log_message "Processing archive records from database..."

# Read the database output line by line
# Each line is expected to be "ARCHIVE_FILECHECKSUM" due to `sed 's/ //g'`
while IFS= read -r line; do
    # Check if the line is empty (can happen with some `db2 -x` outputs)
    if [ -z "$line" ]; then
        continue
    fi

    # Extract the database checksum (last 64 characters)
    # Ensure your CHECKSUM column is indeed CHARACTER(64) and filled.
    # If it can be shorter or NULL, this extraction logic will need adjustment.
    DB_CHECKSUM="${line: -64}"
    # Extract the archive filename (everything before the last 64 characters)
    ARCHIVE_AUDIT_DB_FILENAME="${line:0:${#line}-64}"

    log_message "  Processing DB Entry: ${ARCHIVE_AUDIT_DB_FILENAME}"

    FULL_PHYSICAL_PATH="${ARCHIVE_BASE_DIR}${ARCHIVE_AUDIT_DB_FILENAME}"

    if [ ! -f "${FULL_PHYSICAL_PATH}" ]; then
        alert_message "Physical file NOT FOUND: ${FULL_PHYSICAL_PATH}"
        ((MISSING_COUNT++))
        continue
    fi

    # Generate checksum for the physical file
    CURRENT_FILE_CHECKSUM=$(openssl dgst -sha256 "${FULL_PHYSICAL_PATH}" | awk '{print $NF}')
    
    if [ -z "$CURRENT_FILE_CHECKSUM" ]; then
        alert_message "Could not generate checksum for file: ${FULL_PHYSICAL_PATH}"
        continue
    fi

    # Compare checksums
    if [ "$CURRENT_FILE_CHECKSUM" = "$DB_CHECKSUM" ]; then
        log_message "  Checksum MATCH for ${ARCHIVE_AUDIT_DB_FILENAME}"
    else
        alert_message "Checksum MISMATCH for ${ARCHIVE_AUDIT_DB_FILENAME}"
        alert_message "    DB Checksum      : ${DB_CHECKSUM}"
        alert_message "    Calculated Checksum: ${CURRENT_FILE_CHECKSUM}"
        ((MISMATHCED_COUNT++))
    fi

done < "$DB_DATA_FILE"

# The trap function will handle cleaning up the temporary file on exit.

log_message "\n--- Audit Summary ---"
if [ "$MISMATHCED_COUNT" -gt 0 ]; then
    alert_message "Total Checksum MISMATCHES detected: ${MISMATHCED_COUNT}"
fi
if [ "$MISSING_COUNT" -gt 0 ]; then
    alert_message "Total physical files NOT FOUND: ${MISSING_COUNT}"
fi

if [ "$MISMATHCED_COUNT" -eq 0 ] && [ "$MISSING_COUNT" -eq 0 ]; then
    log_message "All database checksums match their corresponding physical file checksums, and all files were found."
else
    alert_message "Audit completed with issues. Check log file for details."
fi

log_message "Script finished."
exit 0
