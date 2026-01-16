#!/bin/bash
# Author: The Kevin
# Merged and optimized script for DB2 Audit Management
# Corrected: Removed GNU 'find -maxdepth' option for AIX compatibility

# --- Configuration ---
# IMPORTANT: Adjust these paths and names to match your environment

# DB2 Instance Specifics
CUR_SID="$DB2DBDFT" # Your DB2 SID, derived from DB2DBDFT. Example: "CAI"
DB_SCHEMA="AUDIT" # Your specified schema is AUDIT

ARCHIVEPROCESSED="Archiveprocessed"
EXTRACTPROCESSED="Extractprocessed"
# The final directory, the processed CSV files is below. Not needed here but
# included for documentation purposes.
FINALEXTRACT="FinalExtract" # This will be a subdirectory under EXTRACT_OUTPUT_DIR

# Directory where the raw .del audit files and extracted .del files are located
AUDIT_DEL_FILES_DIR="/db2/$CUR_SID/AUDIT/audarchive" # <--- IMPORTANT: Adjust this path

# Directory where raw archived audit files are located (same as AUDIT_DEL_FILES_DIR in this setup)
ARCHIVE_DIR="$AUDIT_DEL_FILES_DIR"

# The SINGLE directory for all extracted CSVs (same as AUDIT_DEL_FILES_DIR for consistency with script 1)
EXTRACT_OUTPUT_DIR="${AUDIT_DEL_FILES_DIR}/${EXTRACTPROCESSED}"

# Directory where processed original archived audit files will be moved
PROCESSED_ARCHIVE_DIR="${AUDIT_DEL_FILES_DIR}/${ARCHIVEPROCESSED}"

# Full path for the final extracts
FINAL_EXTRACT_BASE_DIR="${EXTRACT_OUTPUT_DIR}/${FINALEXTRACT}"

#################################################################################
## for the sake of readability, I'll collect a sample file structure
##
## $AUDIT_DEL_FILES_DIR    = /db2/$CUR_SID/AUDIT/audarchive
## $ARCHIVE_DIR            = /db2/$CUR_SID/AUDIT/audarchive - IN CASE THE $AUDIT_DEL_FILES_DIR IS OVERLAID
## $PROCESSED_ARCHIVE_DIR  = /db2/$CUR_SID/AUDIT/audarchive/Archiveprocessed
## $EXTRACT_OUTPUT_DIR     = /db2/$CUR_SID/AUDIT/audarchive/Extractprocessed
## $FINAL_EXTRACT_BASE_DIR = /db2/$CUR_SID/AUDIT/audarchive/Extractprocessed/FinalExtract - used in a later script
## The latter are the files sent over to the auditors on the server in India.
############################################################################################
# --- Logging Setup ---
SCRIPT_NAME=$(basename "$0")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGDIR="/db2/$CUR_SID/AUDIT/log" # Ensure this directory exists or create it
TEMP_LOGFILE="/tmp/${SCRIPT_NAME}_${TIMESTAMP}_$$.log"
FINAL_LOGFILE="${LOGDIR}/${SCRIPT_NAME}_${TIMESTAMP}.log"

# Create LOGDIR if it doesn't exist
mkdir -p "$LOGDIR" || { echo "Error: Failed to create log directory '$LOGDIR'. Exiting." >&2; exit 1; }

# Redirect stdout and stderr to tee for console and file logging
# This ensures all script output goes to both console and the temporary log file
exec > >(tee "$TEMP_LOGFILE") 2>&1

echo "Script ${SCRIPT_NAME} started at $(date)"
echo "DB2 SID (DB2DBDFT): $CUR_SID"
echo "Raw archived audit files directory: $ARCHIVE_DIR"
echo "Extracted DEL files and auditlobs will go to: $EXTRACT_OUTPUT_DIR"
echo "Original archived files (after processing) will be moved to: $PROCESSED_ARCHIVE_DIR"
echo "Final extracted audit files will go to: $FINAL_EXTRACT_BASE_DIR"
echo "Temporary log file: $TEMP_LOGFILE"
echo "Final log file will be: $FINAL_LOGFILE"
echo "--------------------------------------------------------------------------------------------------"

# --- Email Configuration ---
# IMPORTANT: Configure these email settings
EMAIL_RECIPIENT="kevin_fries@colpal.com" # Change to the actual recipient email address
EMAIL_SENDER="kevin_fries@colpal.com"     # Change to the sender email address (often a system account)
EMAIL_SUBJECT_PREFIX="DB2 Audit Script - /db2/CAI/AUDIT/audsrc/procmove.sh" # Prefix for email subjects

# --- Files and Tables to Handle ---
declare -a FILES_TO_HANDLE=(
    "audit.del"
    "checking.del"
    "secmaint.del"
    "objmaint.del"
    "validate.del"
    "sysadmin.del"
    "context.del"
    "execute.del"
    "auditlobs"
)

declare -a TABLES_TO_HANDLE=(
    "audit"
    "checking"
    "secmaint"
    "objmaint"
    "validate"
    "sysadmin"
    "context"
    "execute"
)

# You can define specific field selections for tables here if needed.
# If a table is not in this array, it defaults to SELECT *.
# Example:
declare -A TABLE_FIELD_SELECTIONS
# TABLE_FIELD_SELECTIONS["audit"]="EVENT_ID,EVENT_DATE,EVENT_TYPE"
# TABLE_FIELD_SELECTIONS["validate"]="USER_ID,VALIDATION_STATUS"


# --- Functions ---

# Function to send an email notification
# Arguments:
#   $1: Email subject
#   $2: Email body (optional, if not provided, log file content will be used)
send_email_notification() {
    local subject="$1"
    local body="$2"

    if [ -z "$body" ]; then
        # If no body is provided, use the content of the temporary log file
        if [ -f "$TEMP_LOGFILE" ]; then
            body=$(cat "$TEMP_LOGFILE")
        else
            body="Log file not found at $TEMP_LOGFILE. No detailed log available."
        fi
    fi

    echo "Attempting to send email notification to ${EMAIL_RECIPIENT}..."
    # Using 'mail' command, commonly available on AIX.
    # The -r option for sender might require sendmail configuration.
    # If -r doesn't work, remove it and rely on system default sender.
    #echo "$body" | mail -s "${EMAIL_SUBJECT_PREFIX}: ${subject}" "${EMAIL_RECIPIENT}" -r "${EMAIL_SENDER}"
    echo "$body" | mail -s "${EMAIL_SUBJECT_PREFIX}: ${subject}" "${EMAIL_RECIPIENT}" -r "${EMAIL_SENDER}" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Email notification sent successfully."
    else
        echo "ERROR: Failed to send email notification. Check mail configuration and logs." >&2
    fi
}

# Function to handle script exit and log file movement
# Arguments:
#   $1: The exit code of the script
exit_script() {
    local exit_code="$1"
    local log_content=""

    echo "--------------------------------------------------------------------------------------------------"
    echo "Script ${SCRIPT_NAME} completed at $(date) with exit code $exit_code."

    # Capture log content before moving the file, in case the move fails
    if [ -f "$TEMP_LOGFILE" ]; then
        log_content=$(cat "$TEMP_LOGFILE")
    else
        log_content="Temporary log file '$TEMP_LOGFILE' not found."
    fi

    # Attempt to move the temporary log file to its final location
    if mv "$TEMP_LOGFILE" "$FINAL_LOGFILE"; then
        echo "Log written to $FINAL_LOGFILE" >/dev/tty # Write to console directly
    else
        echo "Error: Failed to move log from $TEMP_LOGFILE to $FINAL_LOGFILE." >/dev/tty
        echo "Log content (if any) is below:" >/dev/tty
        echo "$log_content" >/dev/tty # Print captured temp log content to console if move fails
    fi

    # Send email notification if the script exited with an error
    if [ "$exit_code" -ne 0 ]; then
        send_email_notification "FAILURE - Script exited with code $exit_code" "$log_content"
    else
        send_email_notification "SUCCESS - Script completed successfully" "$log_content"
    fi

    exit "$exit_code"
}

# Function to check if a file is empty
is_file_empty() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo "File does not exist: ${file_path}"
        return 0 # Treat non-existent as "empty" for the purpose of not processing it
    fi
    # -s returns true if file exists and has size greater than zero.
    # We want to know if it's NOT greater than zero, i.e., empty or non-existent.
    if [ ! -s "$file_path" ]; then
        return 0 # File is empty (or non-existent, handled above)
    else
        return 1 # File is NOT empty
    fi
}

# Function to check if a DB2 table is empty
is_db2_table_empty() {
    local full_table_name="$1"
    # Use awk to extract the number, more portable than grep -Eo
    local row_count=$(db2 "SELECT COUNT(*) FROM ${full_table_name}" | awk '/--/{next} /[0-9]+/{print $1; exit}')

    if [ $? -ne 0 ]; then
        echo "ERROR: Could not query table ${full_table_name}. May not exist or permissions issue."
        return 2 # Indicate an error
    fi

    if [ "${row_count}" -eq 0 ]; then
        return 0 # Table is empty
    else
        return 1 # Table is NOT empty
    fi
}

# --- Script Start ---

# --- Authentication and Instance Owner Check ---
CURRENT_OS_USER=$(whoami)
DB2_INSTANCE_OWNER="db2${CUR_SID,,}" # Assuming CUR_SID holds the instance owner's username

echo "Checking user permissions..."
echo "Current OS user: ${CURRENT_OS_USER}"
echo "Expected DB2 instance owner: ${DB2_INSTANCE_OWNER}"

# Check if DB2DBDFT environment variable is set
if [ -z "$CUR_SID" ]; then
    echo "ERROR: DB2DBDFT environment variable is not set. Cannot determine instance owner."
    echo "Please ensure you are running this script from the DB2 instance owner's environment or set DB2DBDFT."
    exit_script 1
fi

# Check if the current user is the DB2 instance owner
if [ "$CURRENT_OS_USER" != "$DB2_INSTANCE_OWNER" ]; then
    echo "ERROR: You are not the DB2 instance owner."
    echo "This script must be run by the DB2 instance owner (${DB2_INSTANCE_OWNER})."
    exit_script 1
fi
echo "User check passed: Current user is the DB2 instance owner."
echo "--------------------------------------------------------"

# --- Main Processing Logic ---

# Ensure necessary directories exist
mkdir -p "$EXTRACT_OUTPUT_DIR" || { echo "Error: Failed to create extract output directory '$EXTRACT_OUTPUT_DIR'. Exiting." >&2; exit_script 1; }
mkdir -p "$PROCESSED_ARCHIVE_DIR" || { echo "Error: Failed to create processed archive directory '$PROCESSED_ARCHIVE_DIR'. Exiting." >&2; exit_script 1; }
mkdir -p "$FINAL_EXTRACT_BASE_DIR" || { echo "Error: Failed to create final extract output directory '$FINAL_EXTRACT_BASE_DIR'. Exiting." >&2; exit_script 1; }


#---
## Part 1: Extract and Load Audit Files (Populate DB2 tables with new data)
#---
echo "Part 1: Extracting audit records from raw archived files and loading into DB2 tables..."
echo "--------------------------------------------------------"

# Check if the raw archive directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "Error: Raw archive directory '$ARCHIVE_DIR' does not exist. Exiting."
    exit_script 1
fi

ARCHIVED_FILES_TO_PROCESS=()
while IFS= read -r file; do
    if [[ ! "$file" == "${PROCESSED_ARCHIVE_DIR}/"* ]]; then
        ARCHIVED_FILES_TO_PROCESS+=("$file")
    fi
done < <(find "$ARCHIVE_DIR" -type f -name "db2audit.*.log.*" 2>/dev/null | sort)

if [ ${#ARCHIVED_FILES_TO_PROCESS[@]} -eq 0 ]; then
    echo "No raw archived audit files found in '$ARCHIVE_DIR' that need processing. Nothing to extract or load in this run."
    # If no files, we still proceed to Parts 2 and 3, which will handle cleanup/export of existing data.
else
    echo "Files to be processed (total: ${#ARCHIVED_FILES_TO_PROCESS[@]}):"
    printf '%s\n' "${ARCHIVED_FILES_TO_PROCESS[@]}" # Print files one per line
    echo "--------------------------------------"
    echo "Found raw archived audit files. Starting single extraction and bulk loading..."
    echo "--------------------------------------------------------------------------------------------------"

    # Connect to DB2 for loading
    echo "Connecting to DB2 database: ${CUR_SID} for loading..."
    db2 connect to "$CUR_SID"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to connect to database ${CUR_SID}. Aborting data loading."
        exit_script 1
    fi
    echo "Successfully connected to DB2 for loading."

    # --- Step 1.1: Perform the extraction for ALL files in one go ---
    echo "Executing: db2audit extract delasc TO \"$EXTRACT_OUTPUT_DIR\" FROM FILES" "${ARCHIVED_FILES_TO_PROCESS[@]}"
    db2audit extract delasc TO "$EXTRACT_OUTPUT_DIR" FROM FILES "${ARCHIVED_FILES_TO_PROCESS[@]}"
    extract_status=$?

    if [ $extract_status -eq 0 ]; then
        echo "Successfully extracted all eligible archived files to '$EXTRACT_OUTPUT_DIR'."
        ls -l "$EXTRACT_OUTPUT_DIR"/*.del "$EXTRACT_OUTPUT_DIR"/auditlobs 2>/dev/null

        # --- Step 1.2: Load DB2 tables from the consolidated .del files ---
        echo "Loading DB2 tables from consolidated .del files in '$EXTRACT_OUTPUT_DIR'..."
        for table in "${TABLES_TO_HANDLE[@]}"; do
            DEL_FILE="${EXTRACT_OUTPUT_DIR}/${table}.del"
            LOAD_MESSAGE_FILE="/tmp/load_${table}.msg"
            FULL_TABLE_NAME="${DB_SCHEMA}.${table}"

            if [ -f "$DEL_FILE" ]; then
                if is_file_empty "${DEL_FILE}"; then
                    echo "  Warning: .del file is empty for table ${FULL_TABLE_NAME} at ${DEL_FILE}. Skipping load."
                    continue
                fi

                echo "  Loading table ${FULL_TABLE_NAME} from ${DEL_FILE}..."
                LOAD_COMMAND_PREFIX="LOAD FROM '${DEL_FILE}' OF DEL"
                LOAD_COMMAND_SUFFIX="INSERT INTO ${FULL_TABLE_NAME} NONRECOVERABLE"
                MESSAGES_CLAUSE="MESSAGES '${LOAD_MESSAGE_FILE}'"
                MIDDLE_COMMAND_PART=""

                if [ "$table" == "execute" ] || [ "$table" == "context" ]; then
                    MIDDLE_COMMAND_PART="MODIFIED BY LOBSINFILE"
                else
                    MIDDLE_COMMAND_PART="MODIFIED BY DELPRIORITYCHAR"
                fi
                FINAL_LOAD_COMMAND="${LOAD_COMMAND_PREFIX} ${MIDDLE_COMMAND_PART} ${MESSAGES_CLAUSE} ${LOAD_COMMAND_SUFFIX}"

                echo "  Executing DB2 LOAD: ${FINAL_LOAD_COMMAND}"
                db2 "${FINAL_LOAD_COMMAND}"

                LOAD_EXIT_CODE=$?
                if [ "$LOAD_EXIT_CODE" -eq 0 ] || [ "$LOAD_EXIT_CODE" -eq 4 ]; then
                    echo "  Successfully loaded table: ${FULL_TABLE_NAME}"
                else
                    echo "  ERROR: Failed to load table: ${FULL_TABLE_NAME} from '${DEL_FILE}'. Check '${LOAD_MESSAGE_FILE}' for details and DB2 diagnostic logs. Continuing to next table."
                fi
               
                if [ -f "$LOAD_MESSAGE_FILE" ]; then
                    TARGET_MSG_FILE="${LOGDIR}/load_${table}_${TIMESTAMP}.msg"
                    echo "  Moving load message file from '${LOAD_MESSAGE_FILE}' to '${TARGET_MSG_FILE}'."
                    mv "$LOAD_MESSAGE_FILE" "$TARGET_MSG_FILE"
                    if [ $? -eq 0 ]; then
                        echo "  Successfully moved load message file for ${FULL_TABLE_NAME}."
                    else
                        echo "  WARNING: Failed to move load message file for ${FULL_TABLE_NAME}. It might still be in /tmp/." >&2
                    fi
                else
                    echo "  INFO: No load message file found at '${LOAD_MESSAGE_FILE}' for ${FULL_TABLE_NAME}."
                fi
            else
                echo "  Warning: .del file not found for table ${FULL_TABLE_NAME} at ${DEL_FILE}. Skipping load for this table."
            fi
        done # End of for table in TABLES_TO_HANDLE (Load)
        echo "Finished loading tables from consolidated .del files."

        # --- Step 1.3: Move ALL processed original archive files ---
        echo "Moving all ${#ARCHIVED_FILES_TO_PROCESS[@]} original archived files to '$PROCESSED_ARCHIVE_DIR'."
        for file_to_move in "${ARCHIVED_FILES_TO_PROCESS[@]}"; do
            mv "$file_to_move" "$PROCESSED_ARCHIVE_DIR/"
            if [ $? -eq 0 ]; then
                echo "  Successfully moved '$file_to_move'."
            else
                echo "  ERROR: Failed to move '$file_to_move' to '$PROCESSED_ARCHIVE_DIR'. Manual intervention may be required." >&2
            fi
        done # End of for file_to_move (Move processed archives)
        echo "Finished moving original archived files."

    else # If db2audit extract itself failed
        echo "ERROR: db2audit extract failed for the batch of files (exit code: $extract_status). Check DB2 audit logs for details. Skipping load and move of archive files." >&2
    fi

    # Disconnect from DB2 after the main processing (extraction and loading)
    db2 connect reset
    echo "Disconnected from DB2."
    echo "Finished batch extraction and loading process."
    echo "--------------------------------------------------------"
fi # End of if [ ${#ARCHIVED_FILES_TO_PROCESS[@]} -eq 0 ] (Part 1 main block)

# Explicitly disconnect if connected from Part 1, to ensure clean state for next parts
db2 connect reset 2>/dev/null # Suppress errors if not connected.

#---
## Part 2: Exporting DB2 tables to final extract files (Export newly loaded data)
#---
echo "Part 2: Exporting DB2 tables to final extract files..." # Renamed from Part 3 for logical flow
echo "--------------------------------------------------------"

# Reconnect to DB2 for export
db2 connect to "$CUR_SID"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to database ${CUR_SID} for export. Aborting table export."
    exit_script 1
fi
echo "Successfully connected to DB2 for export."

for table in "${TABLES_TO_HANDLE[@]}"; do
    # Get current timestamp for filename
    CURRENT_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
   
    # Check if a specific field selection is defined for this table
    # You'll need to define a mechanism to store field selections, e.g., an associative array or a case statement.
    # For demonstration, let's assume you have an associative array named TABLE_FIELD_SELECTIONS
    # Example: declare -A TABLE_FIELD_SELECTIONS
    # TABLE_FIELD_SELECTIONS["Table1"]="COL1,COL2"
    # TABLE_FIELD_SELECTIONS["Table2"]="COL_A,COL_B,COL_C"
   
    FIELD_SELECTION="${TABLE_FIELD_SELECTIONS[$table]}"
    if [ -z "$FIELD_SELECTION" ]; then
        # If no specific selection is defined, use SELECT *
        SQL_SELECT_STATEMENT="SELECT *"
    else
        # Use the defined field selection
        SQL_SELECT_STATEMENT="SELECT ${FIELD_SELECTION}"
    fi

    FULL_TABLE_NAME="${DB_SCHEMA}.${table}"

    # Check for records before exporting (should have records if Part 1 was successful)
    RECORD_COUNT=$(db2 "SELECT COUNT(*) FROM ${FULL_TABLE_NAME}" | awk '/--/{next} /[0-9]+/{print $1; exit}')

    if [ "$RECORD_COUNT" -gt 0 ]; then
        FINAL_EXTRACT_FILE="${FINAL_EXTRACT_BASE_DIR}/${CURRENT_TIMESTAMP}_Final_${table}.del" # Use FINAL_EXTRACT_BASE_DIR
        echo "Exporting table ${FULL_TABLE_NAME} with ${RECORD_COUNT} records to ${FINAL_EXTRACT_FILE} using '${SQL_SELECT_STATEMENT}'..."
        db2 "EXPORT TO '${FINAL_EXTRACT_FILE}' OF DEL ${SQL_SELECT_STATEMENT} FROM ${FULL_TABLE_NAME}" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "Successfully exported table: ${FULL_TABLE_NAME}"
        else
            echo "ERROR: Failed to export table: ${FULL_TABLE_NAME}. Manual check required."
        fi
    else
        echo "INFO: No records found in table ${FULL_TABLE_NAME}. Skipping export."
    fi
done # End of for table in TABLES_TO_HANDLE (Export)

# Disconnect from DB2 after export
db2 connect reset
echo "Disconnected from DB2 after export."
echo "Finished exporting tables."
echo "--------------------------------------------------------"

#---
## Part 3: Clean Up Extracted .del Files and Truncate DB2 Audit Tables (Cleanup after export)
#---
echo "Part 3: Cleaning up extracted .del files and truncating DB2 audit tables..." # Renamed from Part 2 for logical flow
echo "--------------------------------------------------------"

# Part 3.1: Check and Null out Files
echo "Part 3.1: Checking and nulling out extracted audit .del files and auditlobs..."
for file in "${FILES_TO_HANDLE[@]}"; do
    FILE_PATH="${AUDIT_DEL_FILES_DIR}/${EXTRACTPROCESSED}/${file}"
    echo "Checking file: ${FILE_PATH}"

    if is_file_empty "${FILE_PATH}"; then
        echo "  File is already empty or does not exist: ${FILE_PATH} - Skipping null out."
    else
        echo "  File is NOT empty: ${FILE_PATH} - Nulling it out."
        > "${FILE_PATH}"
        if [ $? -eq 0 ]; then
            echo "  Successfully nulled out: ${FILE_PATH}"
        else
            echo "  ERROR: Failed to null out: ${FILE_PATH}"
        fi
    fi
done # End of for file in FILES_TO_HANDLE (Null out files)
echo "Finished checking and nulling out files."
echo "--------------------------------------------------------"

# Part 3.2: Check and Truncate DB2 Tables
echo "Part 3.2: Checking and truncating DB2 tables in schema ${DB_SCHEMA}..."

# Connect to DB2 for truncation
echo "Connecting to DB2 database: ${CUR_SID} for truncation..."
db2 connect to "$CUR_SID"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to database ${CUR_SID}. Aborting table truncation."
    exit_script 1
fi
echo "Successfully connected to DB2 for truncation."

for table in "${TABLES_TO_HANDLE[@]}"; do
    FULL_TABLE_NAME="${DB_SCHEMA}.${table}"
    echo "Checking table: ${FULL_TABLE_NAME}"

    if is_db2_table_empty "${FULL_TABLE_NAME}"; then
        if [ $? -eq 0 ]; then # Table is empty
            echo "  Table is already empty: ${FULL_TABLE_NAME} - Skipping truncation."
        else # is_db2_table_empty returned 2 (error)
            echo "  ERROR during check for table ${FULL_TABLE_NAME}. Skipping truncation."
        fi
    else # Table is NOT empty
        echo "  Table is NOT empty: ${FULL_TABLE_NAME} - Truncating it."
        db2 "TRUNCATE TABLE ${FULL_TABLE_NAME} IMMEDIATE"

        if [ $? -eq 0 ]; then
            echo "  Successfully truncated table: ${FULL_TABLE_NAME}"
        else
            echo "  ERROR: Failed to truncate table: ${FULL_TABLE_NAME}. Manual intervention may be required."
        fi
    fi
done # End of for table in TABLES_TO_HANDLE (Truncate)

# Disconnect from DB2 after truncation
db2 connect reset
echo "Disconnected from DB2 after truncation."
echo "Finished checking and truncating tables."
echo "--------------------------------------------------------"

# Exit successfully
exit_script 0
