#!/bin/bash
#############################################################################
# This is intended to be quick and dirty. Run only with the instance owner. #
#############################################################################

# Function to execute a command and log its status
execute_and_log() {
    local cmd="$1"
    echo "--------------------------------------------------------"
    echo "INFO: Executing command: $cmd"

    # Execute the command
    eval "$cmd"

    # Check the exit code of the last command
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Command completed successfully."
    else
        echo "ERROR: Command failed with exit code $?."
        exit 1
    fi
    echo "--------------------------------------------------------"
}

# Get the DB2 instance owner from the configuration
DB2_OWNER=$(db2ilist |head -n 1)
# Get the current user
CURRENT_USER=$(whoami)
# Check if the current user is the DB2 owner
if [ "$CURRENT_USER" = "$DB2_OWNER" ]; then
    echo "Success: The current user ($CURRENT_USER) is the DB2 instance owner."
else
    echo "Error: The user running this script ($CURRENT_USER) is not the DB2 instance owner ($DB2_OWNER)."
    exit 10
fi
