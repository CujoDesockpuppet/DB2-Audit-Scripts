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

# Use the function for each db2 command
execute_and_log 'db2 "CREATE AUDIT POLICY CAPSCHEMA CATEGORIES AUDIT STATUS BOTH, CHECKING STATUS BOTH, CONTEXT STATUS NONE, EXECUTE with data STATUS BOTH, SECMAINT STATUS BOTH, SYSADMIN STATUS BOTH ERROR TYPE AUDIT"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSIS REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAS REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSET REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.FAGLFLEXT REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.FAGLFLEXA REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COBK REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COEP REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COSP REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COSS REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.WITH_ITEM REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNC1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNC3 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFC1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFC3 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MKPF REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MSEG REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKA1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKB1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKAT REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFA1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFB1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFBK REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFM1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNA1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNB1 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNBK REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BC001 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BD001 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BP000 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MARC REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MBEW REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDHDR REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDPOS REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SE16N_CD_KEY REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SE16N_CD_DATA REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MARD REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSIK REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAK REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSID REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAD REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PA0002 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PA0009 REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DBTABLOG REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD02L REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD03M REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD04L REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD09L REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PAHI REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.RFBLG REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDCLS REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd03l REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd04t REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd01L REMOVE POLICY"'
execute_and_log 'db2 "AUDIT TABLE audit.ARCHIVELOGGING REMOVE POLICY"'
execute_and_log 'db2 "audit user db2cai remove policy"'
execute_and_log 'db2 "audit user sapcap remove policy"'
execute_and_log 'db2 "audit table sapcap.zusrpwd1 remove policy"'
execute_and_log 'db2 "audit user db2cap remove policy"'
execute_and_log 'db2 "audit user sapcap remove policy"'
execute_and_log 'db2 "drop audit policy CAPSCHEMA"';
 
