#!/bin/bash

# --- Configuration ---
# DB2 Database Connection Details
DB_NAME="$DB2DBDFT"
# DB_USER="your_db2_username"
# DB_PASSWORD="your_db2_password" # Be cautious with storing passwords directly in scripts. Consider secure alternatives.

# Base directory where archive files are stored.
# The ARCHIVE_FILE in your DB should be relative to this path.
ARCHIVE_BASE_DIR="/db2/$DB2DBDFT/AUDIT/audarchive/Archiveprocessed"

# Log file for output
LOG_FILE="/db2/$DB2DBDFT/AUDIT/log/checksum_audit_$(date +%Y%m%d_%H%M%S).log"

# --- Functions ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

alert_message() {
    echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1" | tee -a "$LOG_FILE"
}

# Function to connect to DB2 and fetch data
get_db_archive_data() {
    # This assumes you have the DB2 client installed and configured,
    # and that you can connect using 'db2' command line.
    # For automated scripts, you might need to handle DB2 profile sourcing or environment variables.

    log_message "Attempting to connect to DB2 database: $DB2DBDFT"
    # log_message "Attempting to connect to DB2 database: $DB2DBDFT as user $DB_USER"
    # Use a temporary file to store DB2 output
    TMP_DB_OUTPUT=$(mktemp)

    # Note: Using `db2 -x` for raw output and `db2 +p` to suppress prompts.
    # Adjust authentication if you use different methods (e.g., trust, client credentials).
    db2 "connect to ${DB2DBDFT}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        alert_message "Failed to connect to DB2 database. Please check credentials and connectivity."
        rm -f "$TMP_DB_OUTPUT"
        return 1
    fi
    log_message "Successfully connected to DB2."

    # Fetch ARCHIVE_FILE and CHECKSUM.
    # Using '|| true' to prevent script from exiting if 'db2' returns non-zero on disconnect
    # due to specific conditions, and we still want to process the output.
    db2 -x "SELECT ARCHIVE_FILE, CHECKSUM FROM audit.archivelogging" | sed 's/ //g' > "$TMP_DB_OUTPUT"

    # Disconnect from DB2
    db2 "connect reset" > /dev/null 2>&1
    db2 terminate > /dev/null 2>&1

    # Check if the temporary file contains data
    if [ ! -s "$TMP_DB_OUTPUT" ]; then
        alert_message "No data retrieved from audit.archivelogging or query failed."
        rm -f "$TMP_DB_OUTPUT"
        return 1
    fi
    
    # Return the path to the temporary file
    echo "$TMP_DB_OUTPUT"
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
    # Split the line into filename and checksum.
    # Assuming ARCHIVE_FILE contains no spaces and CHECKSUM is always 64 chars.
    # This is brittle if ARCHIVE_FILE contains spaces or checksum length changes.
    # A more robust parse would be to use `awk` to split the db2 output on a separator
    # or to avoid `sed 's/ //g'` and split by fixed column width/position.
    # For simplicity and given CHARACTER(64) for CHECKSUM, we'll extract last 64 chars.
    
    # Extract the database checksum (last 64 characters)
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
    # `awk '{print $NF}'` extracts the last field (the checksum value)
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

# Clean up temporary file
rm -f "$DB_DATA_FILE"

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
