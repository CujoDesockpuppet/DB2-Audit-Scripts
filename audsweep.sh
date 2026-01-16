#!/bin/bash
# Usage:
# audsweep.sh SID (the database SID is mandatory)
# It will not care if it's entered in upper or lower case.
# This will converted to upper or lower case as needed.
### Case conversion
##### We use "^^" to convert a variable to upper case as seen below.
##### We use ",," to convert a variable to lower case as seen below.
#### Database SID
#### CUR_SID=${1^^} would take the input value of "cai" and make the
####          value of CUR_SID = "CAI"
##################################
######################################################
# The purpose of ths script is as follows:
#
# Weekly or daily archive of the audit files.
# This will also attempt to check the filesystems
# involved to determine if the source or destination
# filesystems are sufficiently sized.
#######################################################

# Let's set up the constants we need
#######################BEGIN CONSTANTS ###############
########### Constants:
##### Of course you can modifiy all of them. Call them guesses or assumptions if
##### you wish. You can override them if you like, these drive much of the logic.

### Conversion Factor - Best guess at size of extract files
###               vs. the size of the audit archives
###         This isn't used here other than a reporting estimate.

EXTRACT_MULTIPLIER_FUDGE_FACTOR=2.3

### No reason to change this unless for testing. Output to determine that db2pd -
### with the db2sid ID returns the default <sid> database as active.
#### Also see the DB2DBDFT envirenment variable.

ACTIVE_STATUS="Active"

### Reporting files expiration in days.

FILE_EXPIRATION=365 # report cleanup.

# We are checking the state of the three filesystems
## 1. Active Audit Logs (this the the current logs that are written to)
## 2. Archive Audit Log (these are the logs that are archived from point #1)
## 3. Extract Files (these are the files extracted from Point #2)
## We have three disk space evaluations to consider
## We want to know about the state of the following
## a. Active Audit filesystem usage
## b. Archive Audit filesystem usage
## c. Extract Audit filesystem usage
##################################

ACTIVE_AUDIT_THRESHOLD=65 # All are guesses, alter as needed.
ARCHIVE_AUDIT_THRESHOLD=65 # All are guesses, alter as needed.
EXTRACT_AUDIT_THRESHOLD=45 # All are guesses, alter as needed.

##################################END CONSTANTS

# Allow any files created to be read, created and removed as needed

umask 000

# We are setting up a file in /tmp which will be transferred the end of processing
# Additionally an audit trail to determine where the issue occurred
# SCRIPT_PATH is used for troubleshooting.
# Use 'realpath' or a similar method for a robust script path, but we'll stick
# to a version closer to your original for minimal changes.
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Initial check for SID argument before setting up logging
if [ "$#" -lt 1 ]; then
    echo "Error: No arguments supplied - Requires the database SID as an argument" >&2 # Output error to stderr
    echo "Usage: audsweep.sh SID" >&2
    echo "Example: audsweep.sh CAP" >&2
    echo "Input SID is not case sensitive" >&2
    exit 1 # Exit immediately as we can't determine LOGDIR without SID
fi

# Environment and related variables.
CUR_SID=${1^^} # convert to uppercase
DB_USER_SID=${1,,} # lowercase SID
DB_TYPE="db2"
DB_USER=${DB_TYPE}${DB_USER_SID}

# Let's set up where the files are going.
# LOGDIR depends on CUR_SID, so it must be defined after CUR_SID.
LOGDIR="/db2/$CUR_SID/AUDIT/log"

# --- SINGLE INSTANCE LOCKING MECHANISM ---
# We use a directory as a lock. mkdir is an atomic operation.
# The trap command ensures the lock is cleaned up on exit.
LOCK_DIR="/tmp/audsweep_$CUR_SID.lock"

# Attempt to acquire the lock. If the directory already exists,
# another instance of the script is running.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Error: A lock file already exists at '$LOCK_DIR'." >&2
    echo "Another instance of this script for SID '$CUR_SID' may be running." >&2
    exit 100 # Exit code for lock contention
fi

# Set a trap to ensure the lock directory is removed on script exit,
# regardless of whether it's a success (exit 0) or failure.
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# Create LOGDIR if it doesn't exist, as it's needed for the final log location
# and potentially for the temp log if LOGDIR is the same as /tmp.
# This also handles the case where LOGDIR might not be writable by the user,
# providing an early exit.
if [ ! -d "$LOGDIR" ]; then
    echo "Log directory '$LOGDIR' does not exist. Attempting to create it."
    mkdir -p "$LOGDIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create log directory '$LOGDIR'. Exiting." >&2
        exit 1 # Cannot proceed without a log directory
    fi
    echo "Log directory '$LOGDIR' created successfully."
fi

# This is the default schema for the audit table for the CRC check. The table is audited so I strongly suggest you recreate
# the table in a different schema and/or table for testing - For the code to recreate the table in case of an accident, see the end of the script.

AUDIT_SCHEMA=AUDIT
TABLE_NAME=ARCHIVELOGGING

# --- Set up Tee for simultaneous console and file logging ---
# Create a temp log file in /tmp or LOGDIR, if LOGDIR is available.
# We'll use /tmp as it's guaranteed to be writable.
TEMP_LOGFILE="/tmp/audsweep.log.$$"

# Redirect stdout and stderr to tee, which then writes to both console and TEMP_LOGFILE
# The 'tee' command is the key here. It duplicates the output.
# 'tee -a' appends to the file. If you want to overwrite, use 'tee' without '-a'.
# Here we want to overwrite the initial temp file, so just 'tee'.
exec > >(tee "$TEMP_LOGFILE") 2>&1

# Now all `echo` commands will go to both console and the temp log file.

# Let's start with runtime info.
echo "Script ${SCRIPT_PATH} started at $(date)"
echo "Temporary log file: $TEMP_LOGFILE"
echo "Final log directory: $LOGDIR"
echo "--------------------------------------------------------------------------------------------------"


############################################################################################
# Sanitize the input and verify everything exists. We need a database SID passed along
# because the reporting and logging depend on this. So verify the parameter is passed
# If parameter is not passed, exit immediately.
# I haven't created any parameter for debugging at this point but it's child's play to add.
############################################################################################

# Re-check argument, now that logging is set up
if [ "$#" -lt 1 ]; then
    echo "Error: No arguments supplied - Requires the database SID as an argument"
    echo "Please use the format 'audsweep.sh SID'"
    echo "EG: audsweep.sh CAP"
    echo "Input SID is not case sensitive"
    echo "Exiting script with exit code 1 - see code ${SCRIPT_PATH} to determine where it failed"
    # The 'exit_with_log_move' function will handle the log file.
    exit_with_log_move 1 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

# Function to move log and exit, ensuring console message
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
        mkdir -p "$log_dir" 2>/dev/null # Suppress error if already exists
    fi

    # Move the temporary log file to its final destination
    if mv "$temp_log" "$FINAL_LOGFILE" ; then
        echo "Log written to $FINAL_LOGFILE"
    else
        echo "Error: Failed to move log from $temp_log to $FINAL_LOGFILE. Log content below:"
        cat "$temp_log" # Print temp log content to console if move fails
    fi
    exit "$exit_code"
}


# Setup the environemnt variables for recording the entries into the AUDIT.ARCHIVELOGGING table
# Let's start with the Audit Archive directory.
audit_path_line=$(db2audit describe | grep "Archive Path")
ARCHIVE_DIR=$(echo "$audit_path_line" | sed 's/.*"\(.*\)"/\1/')
echo "DB2 Audit Archive Path: $ARCHIVE_DIR"

# Let's start with runtime info.
echo "Script ${SCRIPT_PATH} started at $(date)"
echo "--------------------------------------------------------------------------------------------------"

# --- Environment Variable Check ---

echo "Checking for environment variable: DB2DBDFT"
# Define the name of the directory you want to check/create.
# It's good practice to use a variable for easy modification.

# We're already setting LOGDIR based on CUR_SID/DB2DBDFT logic.
# TARGET_DIRECTORY="/db2/${DB2DBDFT}/AUDIT/log" # This line seems redundant with LOGDIR
# Let's verify DB2DBDFT directly.

# Define the name of the file you want to touch inside the directory.
TARGET_FILE="audsweep_errors.txt"

# Check if the DB2DBDFT environment variable is set and not empty.
# -z "$DB2DBDFT" checks if the string length of $VAR is zero (i.e., empty or unset).
# ! -z "$DB2DBDFT" means "if the string length is NOT zero".

if [ -z "${DB2DBDFT}" ]; then
    echo "Error: The DB2DBDFT environment variable is not set or is empty."
    echo "It's likely not running under the correct db2<sid> user."
    echo "This script is running under user: ${USER}"
    echo "Please set DB2DBDFT before running this script."
    echo "Exiting script with exit code 31 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 31 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
else
    echo "This script is running under user: ${USER}"
    echo "DB2DBDFT is set to: ${DB2DBDFT}"
fi
#### Database SID - convert to uppercase - strictly defensive but saves grief for testing.
# CUR_SID=${1^^} # Already done earlier

# --- Script Logic ---

# Check if the directory exists using the -d operator.
# Strictly defensive, at this point the user and default DB exist
# The -d operator returns true if the file exists and is a directory.
# Using LOGDIR instead of TARGET_DIRECTORY for consistency as it's already defined
if [ ! -d "$LOGDIR" ]; then
    echo "Directory '$LOGDIR' does not exist. Creating it now..."
    mkdir -p "$LOGDIR"

    # Check if mkdir was successful
    if [ $? -eq 0 ]; then
        echo "Directory '$LOGDIR' created successfully."
    else
        echo "Error: Failed to create directory '$LOGDIR'."
        echo "Exiting script with exit code 51 - see code ${SCRIPT_PATH} to determine where it failed"
        exit_with_log_move 51 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
    fi
else
    echo "Directory '$LOGDIR' already exists."
fi

# Now, touch the file inside the directory.
# The 'touch' command creates an empty file if it doesn't exist,
# or updates the timestamp if it does.
FULL_FILE_PATH="$LOGDIR/$TARGET_FILE" # Using LOGDIR here
echo "Attempting to create/update file: $FULL_FILE_PATH"
touch "$FULL_FILE_PATH"

# Check if touch was successful
if [ $? -eq 0 ]; then
    echo "File '$TARGET_FILE' created/updated successfully in '$LOGDIR'."
else
    echo "Error: Failed to create/update file '$TARGET_FILE' in '$LOGDIR'."
    echo "Exiting script with exit code 41 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 41 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

echo "Script finished initial setup."
echo "--------------------------------------------------------------------------------------------------"

#### Logging variables
CUR_DATE=$(date +%Y-%m-%d_%H-%M-%S) # Fixed syntax: `date +%Y-%m-%d_%H-%M-%S`
CUR_USER=$(whoami)
CUR_HOST=$(hostname)
SCRIPT_NAME=$(basename "$0") # Fix: Use basename to get just the script name

#### Mail values for Subject and where it's sent
SUBJECT=$(echo "${CUR_SID} on ${CUR_HOST} Audit Archive Report") # Using CUR_SID directly
TO="Kevin_fries@colpal.com"
#TO="Kevin_fries@colpal.com,esc_dba_group@colpal.com,esc_prod_control@colpal.com"
########################################################################################
# We are checking the state of the three filesystems
## 1. Active Audit Logs (this the the current logs that are written to)
## 2. Archive Audit Log (these are the logs that are archived from point #1)
## 3. Extract Files (these are the files extracted from Point #2)
## We have three disk space evaluations to consider
## We want to know about the state of the following
## a. Active Audit filesystem usage
## b. Archive Audit filesystem usage
## c. Extract Audit filesystem usage
###################################################################################

# Let's get the size of the filesystems and usage percentage.
## We have the following filesystems we care about
## /db2/$SID/AUDIT
## /db2/$SID/AUDIT/audarchive
## /db2/$SID/AUDIT/extract

###############################################################################

#### Database SID

# CUR_SID=${1^^} # Already defined and converted
# DB_USER_SID=${1,,} # Already defined
# DB_TYPE="db2" # Already defined
# DB_USER=${DB_TYPE}${DB_USER_SID} # Already defined
echo "Current Database SID is $CUR_SID"
echo "Database_User running the $0 script is $DB_USER"
# CUR_USER=$(whoami) # Already defined earlier

####### Let's make sure we have the correct user running the script (db2<sid>) and that the DB is up
echo "CUR_USER is: $CUR_USER"

if [[ "$DB_USER" == "$CUR_USER" ]]; then
    echo "Strings are equal - moving on"
    echo "Checking if database $CUR_SID is running."
else
    echo "Strings are not equal"
    echo "CUR_USER is $CUR_USER"
    echo "Database user error: database user is $DB_USER"
    echo "Exiting script with exit code 21 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 21 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

###### DB Active Check
#$ACTIVE_STATUS="Active" ### hard coded constant (see "constants" section.)
# We are using the "db2pd -" command and that's why we check the user earlier.
# The output should look similar to this:

# Database Member 0 -- Active -- Up 40 days 03:16:26 -- Date 2025-05-21-01.26.50.405534

# We only care about the "Active" status.

#awk '{if (FNR>1) print $5}') - The "db2pd - " command leaves a blank first line.
# The "FNR" routine skips the first line

DB_STATUS=$(db2pd - | awk '{if (FNR>1) print $5}')
# echo "$DB_STATUS" " from awk output result" # uncomment if you need to debug
echo "Comparing database status with the constant value for Database status"
echo "Database status is $DB_STATUS"
echo "ACTIVE_STATUS is $ACTIVE_STATUS"
if [[ "$DB_STATUS" == "$ACTIVE_STATUS" ]]; then
    echo "Database $CUR_SID is $DB_STATUS"
    echo "Continuing on with processing"
else
    echo "Error Database $CUR_SID is $DB_STATUS"
    echo "Exiting - database does not appear to be running"
    echo "Exiting script with exit code 22 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 22 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

###### Please fix the below filesystems when they are created. EG: #2 = /db2/$CUR_SID/AUDIT/audarchive and #3 = "extract"

# Fix: You were using "/db2/$CUR_SID/AUDIT" for all three df commands.
# You need to specify the correct paths for each filesystem.
ACTIVE_AUDITUSAGE=$(df -Pk "/db2/$CUR_SID/AUDIT" | awk 'NR==2{print $5}' | cut -d'%' -f1) # NR==2 for data line
echo "Active Audit Log Usage = $ACTIVE_AUDITUSAGE%"

ARCHIVE_AUDITUSAGE=$(df -Pk "/db2/$CUR_SID/AUDIT/audarchive" | awk 'NR==2{print $5}' | cut -d'%' -f1)
echo "Archive Audit Usage = $ARCHIVE_AUDITUSAGE%"

EXTRACT_AUDITUSAGE=$(df -Pk "/db2/$CUR_SID/AUDIT/extract" | awk 'NR==2{print $5}' | cut -d'%' -f1)
echo "Extract Audit Usage = $EXTRACT_AUDITUSAGE%"


if [ "$ACTIVE_AUDITUSAGE" -lt "$ACTIVE_AUDIT_THRESHOLD" ]; then
    echo "There is enough space, continuing."
    echo "ACTIVE_AUDITUSAGE is $ACTIVE_AUDITUSAGE% and ACTIVE_AUDIT_THRESHOLD is $ACTIVE_AUDIT_THRESHOLD%"
else
    echo "There is not enough space, we will stop here."
    echo "ACTIVE_AUDITUSAGE is $ACTIVE_AUDITUSAGE% and ACTIVE_AUDIT_THRESHOLD is $ACTIVE_AUDIT_THRESHOLD%"
    echo "Exiting script with exit code 61 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 61 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi
#
if [ "$ARCHIVE_AUDITUSAGE" -lt "$ARCHIVE_AUDIT_THRESHOLD" ]; then
    echo "There is enough space, continuing."
    echo "ARCHIVE_AUDITUSAGE percentage is $ARCHIVE_AUDITUSAGE% and ARCHIVE_AUDIT_THRESHOLD percentage is $ARCHIVE_AUDIT_THRESHOLD%"
else
    echo "There is not enough space, we will stop here."
    echo "ARCHIVE_AUDITUSAGE percentage is $ARCHIVE_AUDITUSAGE% and ARCHIVE_AUDIT_THRESHOLD percentage is $ARCHIVE_AUDIT_THRESHOLD%"
    echo "Exiting script with exit code 62 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 62 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi
#
if [ "$EXTRACT_AUDITUSAGE" -lt "$EXTRACT_AUDIT_THRESHOLD" ]; then
    echo "There is enough space, continuing."
    echo "EXTRACT_AUDITUSAGE percentage is $EXTRACT_AUDITUSAGE% and EXTRACT_AUDIT_THRESHOLD percentage is $EXTRACT_AUDIT_THRESHOLD%"
else
    echo "There is not enough space, we will stop here."
    echo "EXTRACT_AUDITUSAGE percentage is $EXTRACT_AUDITUSAGE% and EXTRACT_AUDIT_THRESHOLD percentage is $EXTRACT_AUDIT_THRESHOLD%"
    echo "Exiting script with exit code 63 - see code ${SCRIPT_PATH} to determine where it failed"
    exit_with_log_move 63 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
fi

# There are both an instance and a db-specific file generated.
# Next we want the sizes of the files to be archived from the active logging in the AUDIT directory.
## Ensure there's enough space in the audarchive directory.
echo "Active audit freespace"
ACTIVE_AUDIT_FREESPACE=$(df -Pk "/db2/$CUR_SID/AUDIT" | awk 'NR==2{print $4}') # Print available space (column 4)
echo "There is this much Active Audit Freespace - $ACTIVE_AUDIT_FREESPACE KB"
echo "Archive audit freespace"
ARCHIVE_AUDIT_FREESPACE=$(df -Pk "/db2/$CUR_SID/AUDIT/audarchive" | awk 'NR==2{print $4}') # Print available space
echo "There is this much Archive Audit Freespace - $ARCHIVE_AUDIT_FREESPACE KB"
echo "Extract audit freespace"
EXTRACT_AUDIT_FREESPACE=$(df -Pk "/db2/$CUR_SID/AUDIT/extract" | awk 'NR==2{print $5}' | cut -d'%' -f1) # Corrected `awk` syntax
echo "There is this much Extract Audit Freespace - $EXTRACT_AUDIT_FREESPACE KB"

ACTIVE_AUDIT_DB_LOGFILE="/db2/$CUR_SID/AUDIT/db2audit.db.$CUR_SID.log.0"
ACTIVE_AUDIT_INSTANCE_LOGFILE="/db2/$CUR_SID/AUDIT/db2audit.instance.log.0"

# Database AUDIT Logs - Active

if [ ! -f "$ACTIVE_AUDIT_DB_LOGFILE" ]; then
    echo "Audit file $ACTIVE_AUDIT_DB_LOGFILE does not exist! Skipping further processing of file."
    ACTIVE_AUDIT_DB_LOGFILE_SZ=0
else
    echo "Flushing the db2audit buffer"
    db2audit flush
    echo "ACTIVE_AUDIT_DB_LOGFILE is $ACTIVE_AUDIT_DB_LOGFILE"
    ACTIVE_AUDIT_DB_LOGFILE_SZ=$(ls -l "$ACTIVE_AUDIT_DB_LOGFILE" | awk '{print int($5 / 1024)}')
    echo "Processing continues of $ACTIVE_AUDIT_DB_LOGFILE"
    echo "Checking destination size vs. DB Audit Log Size"
    echo "$ACTIVE_AUDIT_DB_LOGFILE_SZ KB = ACTIVE_AUDIT_DB_LOGFILE_SZ"
    echo "$ARCHIVE_AUDIT_FREESPACE KB = ARCHIVE_AUDIT_FREESPACE"
    echo "Check for Active freespace"
    if (( "$ACTIVE_AUDIT_DB_LOGFILE_SZ" < "$ARCHIVE_AUDIT_FREESPACE" )); then # Using arithmetic comparison `(( ))`
        echo "Archive log file size is $ACTIVE_AUDIT_DB_LOGFILE_SZ kilobytes and the Audit Archive filesystem has $ARCHIVE_AUDIT_FREESPACE kilobytes free"
        echo "Continuing Archive of $ACTIVE_AUDIT_DB_LOGFILE"
        echo "Command to be run: db2audit archive database $CUR_SID"
        command_output=$(db2audit archive database $CUR_SID)
        ARCHIVE_AUDIT_DB_FILENAME=$(echo "$command_output" | grep "db2audit\.db\.$CUR_SID\.log\.0\." | awk '{for(i=1;i<=NF;i++) if($i ~ /db2audit\.db\.'$CUR_SID'\.log\.0\./) print $i}')
        echo "ARCHIVE_AUDIT_DB_FILENAME: $ARCHIVE_AUDIT_DB_FILENAME"
        echo "Archiving Active Database Log"

        # Check if ARCHIVE_AUDIT_DB_FILENAME is empty. If it is, the archive command might have failed or not returned the expected format.
        if [ -z "$ARCHIVE_AUDIT_DB_FILENAME" ]; then
            echo "Error: Could not determine archived database log filename from db2audit output. Skipping checksum and DB insert for database log."
        else
            checksum=$(openssl dgst -sha256 "${ARCHIVE_DIR}${ARCHIVE_AUDIT_DB_FILENAME}" | awk '{print $NF}') # Concatenate correctly
            echo "Checksum for ${ARCHIVE_AUDIT_DB_FILENAME}: $checksum"

            db2 connect to $CUR_SID
            # FIX: Corrected variable concatenation and removed extra dot
            db2 "INSERT INTO ${AUDIT_SCHEMA}.${TABLE_NAME} (LOG_DATE, ARCHIVE_FILE, CHECKSUM, ARCHIVED_BY) VALUES (CURRENT_TIMESTAMP, '${ARCHIVE_DIR}${ARCHIVE_AUDIT_DB_FILENAME}', '$checksum', '$CUR_USER')"
            if [ $? -eq 0 ]; then
                echo "Successfully inserted record for $ARCHIVE_AUDIT_DB_FILENAME into DB2."
            else
                echo "Error inserting record for $ARCHIVE_AUDIT_DB_FILENAME into DB2."
            fi
            db2 commit
            db2 terminate
        fi
    else
        echo "Not enough space in Archive Audit filesystem for DB log. Skipping archive."
    fi
fi

# Instance logs
# LOGDIR="/db2/$CUR_SID/AUDIT/log" # Already defined and set
echo "Log directory for instance log: $LOGDIR"
echo "--------------------------------------------------------------------------------------------------"

if [ ! -f "$ACTIVE_AUDIT_INSTANCE_LOGFILE" ]; then
    echo "Audit file $ACTIVE_AUDIT_INSTANCE_LOGFILE does not exist! Skipping further processing of file."
    ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ=0
else
    echo "ACTIVE_AUDIT_INSTANCE_LOGFILE is $ACTIVE_AUDIT_INSTANCE_LOGFILE"
    ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ=$(ls -l "$ACTIVE_AUDIT_INSTANCE_LOGFILE" | awk '{print int($5 / 1024)}')
    echo "Processing continues of $ACTIVE_AUDIT_INSTANCE_LOGFILE"
    echo "Checking destination size vs. Instance Audit Log Size"
    echo "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ KB = ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ"
    echo "$ARCHIVE_AUDIT_FREESPACE KB = ARCHIVE_AUDIT_FREESPACE"
    echo "Check for Archive freespace"
    if (( "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ" < "$ARCHIVE_AUDIT_FREESPACE" )); then # Using arithmetic comparison `(( ))`
        echo "Archive log file size is $ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ kilobytes and the Audit Archive filesystem has $ARCHIVE_AUDIT_FREESPACE kilobytes free"
        echo "Continuing Archive of $ACTIVE_AUDIT_INSTANCE_LOGFILE"
        echo "Command to be run: db2audit archive"
        command_output=$(db2audit archive)
        ARCHIVE_AUDIT_INSTANCE_FILENAME=$(echo "$command_output" | grep "db2audit.instance.log\.0\." | awk '{for(i=1;i<=NF;i++) if($i ~ /db2audit.instance.log.0/) print $i}')
        echo "ARCHIVE_AUDIT_INSTANCE_FILENAME: $ARCHIVE_AUDIT_INSTANCE_FILENAME"
        echo "Archiving Active Instance Log $ARCHIVE_AUDIT_INSTANCE_FILENAME"

        if [ -z "$ARCHIVE_AUDIT_INSTANCE_FILENAME" ]; then
            echo "Error: Could not determine archived instance log filename from db2audit output. Skipping checksum and DB insert for instance log."
        else
            checksum=$(openssl dgst -sha256 "${ARCHIVE_DIR}${ARCHIVE_AUDIT_INSTANCE_FILENAME}" | awk '{print $NF}') # Concatenate correctly
            echo "Checksum for ${ARCHIVE_AUDIT_INSTANCE_FILENAME}: $checksum"

            db2 connect to $CUR_SID # Reconnect if necessary
            # FIX: Corrected variable concatenation and removed extra dot
            db2 "INSERT INTO ${AUDIT_SCHEMA}.${TABLE_NAME} (LOG_DATE, ARCHIVE_FILE, CHECKSUM, ARCHIVED_BY) VALUES (CURRENT_TIMESTAMP, '${ARCHIVE_DIR}${ARCHIVE_AUDIT_INSTANCE_FILENAME}', '$checksum', '$CUR_USER')"
            if [ $? -eq 0 ]; then
                echo "Successfully inserted record for $ARCHIVE_AUDIT_INSTANCE_FILENAME into DB2."
            else
                echo "Error inserting record for $ARCHIVE_AUDIT_INSTANCE_FILENAME into DB2."
            fi
            db2 commit
            db2 terminate
        fi
    else
        echo "There is not enough space in Archive Audit filesystem for Instance log. Skipping archive."
        echo "Exiting script with exit code 64 - see code ${SCRIPT_PATH} to determine where it failed"
        exit_with_log_move 64 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
    fi
fi

# Let's work on the math, the extract files will be about 2.3 times larger.
# We don't necessarily look for creating the extract files, We just want to look at how much space they would use for this.
# Extracting the files should be done separately.
# However adding the additional checking here to verify there's enough space in the extract folder can't hurt.

if [ "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ" -eq 0 ]; then
    echo "Skipping instance log - Zero Bytes or not found. This can happen"
else
    INSTANCE_EST_SIZE=$(echo "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ * $EXTRACT_MULTIPLIER_FUDGE_FACTOR" | bc)
    echo "Instance Audit log file size - $INSTANCE_EST_SIZE KB"
    echo "Instance Logfile created and ready for extract"
    echo "Estimated size to be extracted with EXECUTE WITH DATA Active is: $INSTANCE_EST_SIZE KB"
fi

if [ "$ACTIVE_AUDIT_DB_LOGFILE_SZ" -eq 0 ]; then
    echo "Skipping database log - Zero Bytes or not found. This can happen"
else
    DB_EST_SIZE=$(echo "$ACTIVE_AUDIT_DB_LOGFILE_SZ * $EXTRACT_MULTIPLIER_FUDGE_FACTOR" | bc)
    echo "Database Logfile created and ready for extract"
    echo "Estimated size to be extracted with EXECUTE WITH DATA Active is: $DB_EST_SIZE KB"
fi

## If it falls through to here, we are successful.

echo "Exiting script with exit code 0"
exit_with_log_move 0 "$LOGDIR" "$TEMP_LOGFILE" "$0" "$SCRIPT_PATH"
