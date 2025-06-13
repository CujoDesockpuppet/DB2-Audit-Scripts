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
####                value of CUR_SID = "CAI"
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
###                     vs. the size of the audit archives
###       This isn't used here other than a reporting estimate.

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

ACTIVE_AUDIT_THRESHOLD=35 # All are guesses, alter as needed.
ARCHIVE_AUDIT_THRESHOLD=65 # All are guesses, alter as needed.
EXTRACT_AUDIT_THRESHOLD=45 # All are guesses, alter as needed.

##################################END CONSTANTS

# Allow any files created to be read, created and removed as needed

umask 000

# We are setting up a file in /tmp which will be transferred the end of processing 
# Additionally an audit trail to determine where the issue occurred
# SCRIPT_PATH is used for troubleshooting. 

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
# echo "$SCRIPT_PATH" # Debugging only

# Let's set up where the files are going. 
LOGDIR="/db2/$CUR_SID/AUDIT/log"
# Create a temp log file - if the target filesystem somehow fills up,
# you can look for the log file in /tmp
LOGFILE="/tmp/audsweep.log.$$"

# Redirect all output (stdout and stderr) to the log file
exec > "$LOGFILE" 2>&1

# Let's start with runtime info. 
echo "Script ${SCRIPT_PATH}  started at $(date)"
############################################################################################
# Sanitize the input and verify everything exists. We need a database SID passed along
# because the reporting and logging depend on this. So verify the parameter is passed
# If parameter is not passed, exit immediately.
# I haven't created any parameter for debugging at this point but it's child's play to add.
############################################################################################

if [ "$#" -lt 1 ]; then
    echo "No arguments supplied - Requires the database SID as an argument"
    echo "Please use the format 'audsweep.sh SID'"
    echo "EG: audsweep.sh CAP"
    echo "Input SID is not case sensitive"
    echo "exiting script with exit code 1 - see code ${SCRIPT_PATH} to determine where it failed"  
    echo "Script  ${SCRIPT_PATH} completed at $(date)"

    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    # Print message to console (use a new fd, so this line appears on the console)
    exec 3>&1  # open new file descriptor for console output  
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&- 
   exit 1
fi

# Environment and related variables. 
# The syntax below with the two carets (^^) is to make the input to the script into upper case
# must be Bash v4.0 and above (use bash --version to check the current version used)
# Conversly, the double comma (,,) is used to convert to lower case. (may not be needed here)

# --- Environment Variable Check ---

echo "Checking for environment variable: DB2DBDFT"
# Define the name of the directory you want to check/create.
# It's good practice to use a variable for easy modification.

TARGET_DIRECTORY="/db2/${DB2DBDFT}/AUDIT/log"
echo "Checking for directory: $TARGET_DIRECTORY"

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
    echo "exiting script with exit code 31 - see code ${SCRIPT_PATH} to determine where it failed"
    echo "Script  ${SCRIPT_PATH} completed at $(date)"
     # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    # Print message to console (use a new fd, so this line appears on the console)
    exec 3>&1  # open new file descriptor for console output
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
   exit 31 # Exit with an error code indicating failure
else
   echo "This script is running under user: ${USER}"
   echo "DB2DBDFT is set to: ${DB2DBDFT}"
fi
#### Database SID - convert to uppercase - strictly defensive but saves grief for testing. 
CUR_SID=${1^^}

# --- Script Logic ---

# Check if the directory exists using the -d operator.
# Strictly defensive, at this point the user and default DB exist
# The -d operator returns true if the file exists and is a directory.
if [ ! -d "$TARGET_DIRECTORY" ]; then
    # If the directory does not exist (! -d), then create it.
    # mkdir -p:
    #   -p (parents) option creates parent directories as needed.
    #   It also suppresses an error if the directory already exists (though our
    #   'if' condition should prevent this specific case).
 
   echo "Directory '$TARGET_DIRECTORY' does not exist. Creating it now..."
   mkdir -p "$TARGET_DIRECTORY"

    # Check if mkdir was successful
    if [ $? -eq 0 ]; then
        echo "Directory '$TARGET_DIRECTORY' created successfully."
    else
        echo "Error: Failed to create directory '$TARGET_DIRECTORY'."
        echo "exiting script with exit code 51 - see code ${SCRIPT_PATH} to determine where it failed"
        echo "Script  ${SCRIPT_PATH} completed at $(date)"  
        # At the end, move the logfile to the final location with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
        # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
        mv "$LOGFILE" "$FINAL_LOGFILE"
        echo "Log written to $FINAL_LOGFILE" >&3
        # Optional: close the new file descriptor
        exec 3>&-
        exit 51 # Exit with an error code
    fi
else
    echo "Directory '$TARGET_DIRECTORY' already exists."
fi

# Now, touch the file inside the directory.
# The 'touch' command creates an empty file if it doesn't exist,
# or updates the timestamp if it does.
FULL_FILE_PATH="$TARGET_DIRECTORY/$TARGET_FILE"
echo "Attempting to create/update file: $FULL_FILE_PATH"
touch "$FULL_FILE_PATH"

# Check if touch was successful
if [ $? -eq 0 ]; then
    echo "File '$TARGET_FILE' created/updated successfully in '$TARGET_DIRECTORY'."
else
    echo "Error: Failed to create/update file '$TARGET_FILE' in '$TARGET_DIRECTORY'."
    echo "exiting script with exit code 41 - see code ${SCRIPT_PATH} to determine where it failed"
    echo "Script  ${SCRIPT_PATH} completed at $(date)"  
    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 41 # Exit with an error code
fi

echo "Script finished."

#### Logging variables
CUR_DATE=$(date+%Y-%m-%d_%H-%M-%S)
CUR_USER=$(whoami)
CUR_HOST=$(hostname)
SCRIPT_NAME=$0

#### Testing
#LOG_FILE=$CUR_SID"-DBLOGSTATUS-"$CUR_DATE".log" # testing only

#### Mail values for Subject and where it's sent
SUBJECT=$(echo ${UC_CUR_SID} " on " ${CUR_HOST} " Audit Archive Report")
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

CUR_SID=${1^^} # convert to uppercase. May or may not be needed.
DB_USER_SID=${1,,} # lowercase SID to use with database user "db2" + "sid" 
DB_TYPE="db2" # as this is intended for the db2audit facility, no point not hardcoding it. 
DB_USER=${DB_TYPE}${DB_USER_SID}
echo "Current Database SID is $CUR_SID"
echo "Database_User running the $0 script is " "$DB_USER"
CUR_USER=$(whoami)

####### Let's make sure we have the correct user running the script (db2<sid>) and that the DB is up
echo "CUR_USER is: " "$CUR_USER"

if [[ "$DB_USER" == "$CUR_USER" ]]; then
    echo "Strings are equal - moving on"
    echo "Checking if database " "$CUR_SID" " is running."
else
    echo "Strings are not equal"
    echo "CUR_USER is" "$CUR_USER"
    echo "Database user error: database user is " "$DB_USER"
    echo "exiting script with exit code 21 - see code ${SCRIPT_PATH} to determine where it failed"
    echo "Script  ${SCRIPT_PATH} completed at $(date)"
    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
   exit 21
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
echo "Comparing database status with the constant value  for Database status"
echo "Database status is " "$DB_STATUS"
echo "ACTIVE_STATUS is " "$ACTIVE_STATUS"
if [[ "$DB_STATUS" == "$ACTIVE_STATUS" ]]; then
    echo "Database $CUR_SID is $DB_STATUS"
    echo "Continuing on with processing"
else
    echo "Error Database $CUR_SID  is $DB_STATUS"
    echo "exiting - database does not appear to be running"
    echo "exiting script with exit code 22 - see code ${SCRIPT_PATH} to determine where it failed"
    echo "Script  ${SCRIPT_PATH} completed at $(date)"

    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 22
fi

###### Please fix the below filesystems when they are created. EG: #2 = /db2/$CUR_SID/AUDIT/audarchive and #3 = "extract"

ACTIVE_AUDITUSAGE=$(df -k "/db2/$CUR_SID/AUDIT" | awk '{print $4}' | cut -d'%' -f1)
echo "Active Audit Log Usage = $ACTIVE_AUDITUSAGE"
ARCHIVE_AUDITUSAGE=$(df -k "/db2/$CUR_SID/AUDIT" | awk '{print $4}' | cut -d'%' -f1)
echo "Archive Audit Usage = $ARCHIVE_AUDITUSAGE"
EXTRACT_AUDITUSAGE=$(df -k "/db2/$CUR_SID/AUDIT" | awk '{print $4}' | cut -d'%' -f1)
echo "Extract Sudit Usage = $EXTRACT_AUDITUSAGE"

if [ "$ACTIVE_AUDITUSAGE" -lt "$ACTIVE_AUDIT_THRESHOLD" ]; then
    # Create alert
    echo "There is enough space, continuing."
    echo "ACTIVE_AUDITUSAGE is " "$ACTIVE_AUDITUSAGE"
    echo "ACTIVE_AUDIT_THRESHOLD is " "$ACTIVE_AUDIT_THRESHOLD"
else
    echo "There is not enough space, we will stop here."
    echo "ACTIVE_AUDITUSAGE is " "$ACTIVE_AUDITUSAGE"
    echo "ACTIVE_AUDIT_THRESHOLD is " "$ACTIVE_AUDIT_THRESHOLD"
    echo "exiting script with exit code 61 - see code ${SCRIPT_PATH} to determine where it failed"  
    echo "Script  ${SCRIPT_PATH} completed at $(date)"

    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 61
fi
#  
if [ "$ARCHIVE_AUDITUSAGE" -lt "$ARCHIVE_AUDIT_THRESHOLD" ]; then
    echo "There is enough space, continuing."
    echo "ARCHIVE_AUDITUSAGE percentage is " "$ARCHIVE_AUDITUSAGE" " and ARCHIVE_AUDIT_THRESHOLD percentage is " "$ARCHIVE_AUDIT_THRESHOLD"
# Create alert
else
    echo "There is not enough space, we will stop here." 
    echo "ARCHIVE_AUDITUSAGE percentage is " "$ARCHIVE_AUDITUSAGE" " and ARCHIVE_AUDIT_THRESHOLD percentage is " "$ARCHIVE_AUDIT_THRESHOLD"
    echo "exiting script with exit code 62 - see code ${SCRIPT_PATH} to determine where it failed" 
    echo "Script  ${SCRIPT_PATH} completed at $(date)"

    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 62  
fi
#
if [ "$EXTRACT_AUDITUSAGE" -lt "$EXTRACT_AUDIT_THRESHOLD" ]; then
    echo "There is enough space, continuing."   
    echo "EXTRACT_AUDITUSAGE  percentage is " "$EXTRACT_AUDITUSAGE" " and EXTRACT_AUDIT_THRESHOLD percentage is " "$EXTRACT_AUDIT_THRESHOLD"
    # Create alert
else
    echo "There is not enough space, we will stop here."   
    echo "EXTRACT_AUDITUSAGE percentage is " "$EXTRACT_AUDITUSAGE" " and EXTRACT_AUDIT_THRESHOLD percentage is " "$EXTRACT_AUDIT_THRESHOLD"
    echo "exiting script with exit code 63 - see code ${SCRIPT_PATH} to determine where it failed"
    echo "Script  ${SCRIPT_PATH} completed at $(date)"

    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
    # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 63  
fi

# There are both an instance and a db-specific file generated.
# Next we want the sizes of the files to be archived from the active logging in the AUDIT directory.
## Ensure there's enough space in the audarchive directory.
echo "Active audit freespace"
ACTIVE_AUDIT_FREESPACE=$(df -k "/db2/$CUR_SID/AUDIT" | awk '{if (FNR>1) print $3}')
echo "There is this much Active Audit Freespace - $ACTIVE_AUDIT_FREESPACE"
echo "Archive audit freespace"
ARCHIVE_AUDIT_FREESPACE=$(df -k "/db2/$CUR_SID/AUDIT/audarchive" | awk '{if (FNR>1) print $3}')
echo "There is this much Archive Audit Freespace - $ARCHIVE_AUDIT_FREESPACE"
echo "Extract audit freespace"
EXTRACT_AUDIT_FREESPACE=$(df -k "/db2/$CUR_SID/AUDIT/extract" | awk 'f (FNR>1) {print $3}')
echo "There is this much Archive Audit Freespace - $EXTRACT_AUDIT_FREESPACE"

ACTIVE_AUDIT_DB_LOGFILE="/db2/$CUR_SID/AUDIT/db2audit.db.$CUR_SID.log.0"
ACTIVE_AUDIT_INSTANCE_LOGFILE="/db2/$CUR_SID/AUDIT/db2audit.instance.log.0"

# Database AUDIT Logs - Active

if [ ! -f "$ACTIVE_AUDIT_DB_LOGFILE" ]; then
    echo "Audit file " "$ACTIVE_AUDIT_DB_LOGFILE" " does not exist! Skipping further processing of file."
    ACTIVE_AUDIT_DB_LOGFILE_SZ=0
else
    echo "ACTIVE_AUDIT_DB_LOGFILE is" "$ACTIVE_AUDIT_DB_LOGFILE"
    ACTIVE_AUDIT_DB_LOGFILE_SZ=$(ls -l "$ACTIVE_AUDIT_DB_LOGFILE" | awk '{print int($5 / 1024)}')
    #echo "$ACTIVE_AUDIT_DB_LOGFILE";
    echo "Processing continues of " "$ACTIVE_AUDIT_DB_LOGFILE"
    echo "Checking destination size vs. DB Audit Log Size"
    echo "$ACTIVE_AUDIT_DB_LOGFILE_SZ" " = ACTIVE_AUDIT_DB_LOGFILE_SZ"
    echo "$ARCHIVE_AUDIT_FREESPACE" " =  ARCHIVE_AUDIT_FREESPACE"
    echo "check for Active freespace"
    if [ "$ACTIVE_AUDIT_DB_LOGFILE_SZ" -lt "$ARCHIVE_AUDIT_FREESPACE" ]; then
        echo "Archive log file size is " "$ACTIVE_AUDIT_DB_LOGFILE_SZ" " kilobytes and the Audit Archive filesystem has " "$ARCHIVE_AUDIT_FREESPACE" " kilobytes free"
        echo "continuing Archive  of " "$ACTIVE_AUDIT_DB_LOGFILE"
        # db2audit archive database "$CUR_SID" ;
        echo "Command to be run: db2audit archive database $CUR_SID"
        command_output=$(db2audit archive database $CUR_SID)
        ARCHIVE_AUDIT_DB_FILENAME=$(echo "$command_output" | grep "db2audit\.db\.$CUR_SID\.log\.0\." | awk '{for(i=1;i<=NF;i++) if($i ~ /db2audit\.db\.'$CUR_SID'\.log\.0\./) print $i}')
        echo "ARCHIVE_AUDIT_DB_FILENAME  $ARCHIVE_AUDIT_DB_FILENAME"
         echo "Archiving Active Database Log"
    fi
fi

# Instance logs
LOGDIR="/db2/$CUR_SID/AUDIT/log"
echo "Log directory testing" 
echo $LOGDIR
if [ ! -f "$ACTIVE_AUDIT_INSTANCE_LOGFILE" ]; then
    echo "Audit file " "$ACTIVE_AUDIT_INSTANCE_LOGFILE" " does not exist! Skipping further processing of file."
    ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ=0
    echo "Script  ${SCRIPT_PATH} completed at $(date)"   
    echo "exiting script with exit code 0 - see code ${SCRIPT_PATH} to for analysis"
    # At the end, move the logfile to the final location with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
 echo "Final Logfile = ${FINAL_LOGFILE}"
 # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
    mv "$LOGFILE" "$FINAL_LOGFILE"
    echo "Log written to $FINAL_LOGFILE" >&3
    # Optional: close the new file descriptor
    exec 3>&-
    exit 0 
else
    echo "ACTIVE_AUDIT_INSTANCE_LOGFILE is" "$ACTIVE_AUDIT_INSTANCE_LOGFILE"
    ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ=$(ls -l "$ACTIVE_AUDIT_INSTANCE_LOGFILE" | awk '{print int($5 / 1024)}')
    #echo "$ACTIVE_AUDIT_INSTANCE_LOGFILE";
    echo "Processing continues of " "$ACTIVE_AUDIT_INSTANCE_LOGFILE"
    echo "Checking destination size vs. Instance Audit Log Size"
    echo "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ" " = ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ"
    echo "$ARCHIVE_AUDIT_FREESPACE" " =  ARCHIVE_AUDIT_FREESPACE"
    echo "check for Archive freespace"
    if [ "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ" -lt "$ARCHIVE_AUDIT_FREESPACE" ]; then
        echo "Archive log file size is " "$ACTIVE_AUDIT_INSTANCE_LOGFILE_SZ" " kilobytes and the Audit Archive filesystem has " "$ARCHIVE_AUDIT_FREESPACE" " kilobytes free"
        echo "continuing Archive  of " "$ACTIVE_AUDIT_INSTANCE_LOGFILE"
        # db2audit archive;
        echo "Command to be run: db2audit archive"       
        command_output=$(db2audit archive) # Replace with your actual command or put a dummy command here
        ARCHIVE_AUDIT_INSTANCE_FILENAME=$(echo "$command_output" | grep "db2audit.instance.log\.0\." | awk '{for(i=1;i<=NF;i++) if($i ~ /db2audit.instance.log.0/) print $i}')    
        echo "ARCHIVE_AUDIT_INSTANCE_FILENAME $ARCHIVE_AUDIT_INSTANCE_FILENAME"
        echo "Archiving Active Instance Log $ARCHIVE_AUDIT_INSTANCE_FILENAME"
    else
        echo "There is not enough space, we will stop here."
        echo "EXTRACT_AUDITUSAGE percentage is " "$EXTRACT_AUDITUSAGE" " and EXTRACT_AUDIT_THRESHOLD percentage is " "$EXTRACT_AUDIT_THRESHOLD"
        echo "exiting script with exit code 64 - see code ${SCRIPT_PATH} to determine where it failed"
        echo "Script  ${SCRIPT_PATH} completed at $(date)"
        # At the end, move the logfile to the final location with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
        # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
        mv "$LOGFILE" "$FINAL_LOGFILE"
        echo "Log written to $FINAL_LOGFILE" >&3
        # Optional: close the new file descriptor
        exec 3>&-
        exit 64
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
    echo "Instance Audit log file size - $INSTANCE_EST_SIZE"   
    echo "Instance Logfile created and ready for extract"
    echo "Estimated size to be extracted with EXECUTE WITH DATA Active is: " "$INSTANCE_EST_SIZE" " KB"
fi

if [ "$ACTIVE_AUDIT_DB_LOGFILE_SZ" -eq 0 ]; then
    echo "Skipping database log  - Zero Bytes or not found. This can happen"
else
    DB_EST_SIZE=$(echo "$ACTIVE_AUDIT_DB_LOGFILE_SZ * $EXTRACT_MULTIPLIER_FUDGE_FACTOR" | bc)
    echo "Database Logfile created and ready for extract"
    echo "Estimated size to be extracted with EXECUTE WITH DATA Active is: " "$DB_EST_SIZE" " KB"
fi

## If it falls through to here, we are successful. 

echo "exiting script with exit code 0"
        echo "Script  ${SCRIPT_PATH} completed at $(date)"
        # At the end, move the logfile to the final location with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        FINAL_LOGFILE="$LOGDIR/${0}_${TIMESTAMP}.log"
        # FINAL_LOGFILE="${0}_${TIMESTAMP}.log"
        mv "$LOGFILE" "$FINAL_LOGFILE"
        echo "Log written to $FINAL_LOGFILE" >&3
        # Optional: close the new file descriptor
        exec 3>&-
        exit 0
#### Subsequent scripts will extract and CSV type or file and can then format the data into tables. 
# You will be extracting  both the instance and audit logs but only one at a time as the extracts go to the
# same files and will overlay each other.  Thus it's an extract and load to database tables.
# We will not be doing that here and will use other scripting to do that.

## Archive both files and look for any remaining. We will look at the end to see what's laying around.
# The archive commands do the following
## move the active files to the "audarchive" directory. So we check to make sure there's space.
### We then check for sufficient space in the "extract" directory for the archive files.

# We want the target directory remaining space to ensure we have enough to pull it over
# There are extract files that can be generated and these are in CSV format.
# They have the extension *.del and can always be recreated from the archived audit files
#
# With the "execute with data" audit logging turned on the extract files will be about 2.3 times the size of the extract files.
# the reason for this is that there's an "auditlobs" file generated that in some cases is larger than the other extract files.
# We don't have to extract the archived audit logs but they are in somewhat readable format that can be loaded into tables.
