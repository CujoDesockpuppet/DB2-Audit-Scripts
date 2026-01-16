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
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSIS USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAS USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSET USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.FAGLFLEXT USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.FAGLFLEXA USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COBK USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COEP USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COSP USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.COSS USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.WITH_ITEM USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNC1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNC3 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFC1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFC3 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MKPF USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MSEG USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKA1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKB1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SKAT USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFA1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFB1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFBK USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.LFM1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNA1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNB1 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.KNBK USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BC001 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BD001 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BP000 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MARC USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MBEW USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDHDR USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDPOS USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SE16N_CD_KEY USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.SE16N_CD_DATA USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.MARD USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSIK USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAK USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSID USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.BSAD USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PA0002 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PA0009 USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DBTABLOG USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD02L USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD03M USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD04L USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.DD09L USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.PAHI USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.RFBLG USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.CDCLS USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd03l USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd04t USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.dd01L USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE audit.ARCHIVELOGGING USING POLICY CAPSCHEMA"'
execute_and_log 'db2 "AUDIT TABLE SAPCAP.ZUSRPWD1 USING POLICY CAPSCHEMA"'
execute_and_log "db2 \"audit user $DB2_OWNER using policy CAPSCHEMA\""
# execute_and_log 'db2 "audit user db2cai using policy CAPSCHEMA"'
execute_and_log 'db2 "audit user sapcap using policy CAPSCHEMA"'
