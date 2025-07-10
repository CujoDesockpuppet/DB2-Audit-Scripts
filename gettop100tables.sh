#!/bin/bash

# --- Configuration ---
DB_NAME="" # Initialize DB_NAME, will be set from argument or prompt

# --- Usage Function ---
usage() {
    echo "Usage: $0 <DB_NAME>"
    echo ""
    echo "  <DB_NAME>  : The specific database name to connect to for retrieving table sizes."
    echo ""
    echo "Example: $0 SAMPLE"
    exit 1
}

# --- Main Script Execution ---

# 1. Parse Input Parameter (DB_NAME)
if [ -z "$1" ]; then
    echo "ERROR: Database name parameter is required."
    usage
fi

DB_NAME="$1"

# 2. Connect to the database
echo "Attempting to connect to database: $DB_NAME"
db2 connect to "$DB_NAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to database '$DB_NAME'. Please check DB name, instance, and user permissions."
    # For more detailed DB2 error messages, uncomment the line below:
    # db2 connect to "$DB_NAME"
    exit 1
fi
echo "Successfully connected to $DB_NAME."

# 3. Dynamically generate the SQL query and write it to a temporary file
TEMP_SQL_FILE="/tmp/get_top_tables_temp_$(date +%s%N).sql" # Unique temp file

cat <<EOF > "$TEMP_SQL_FILE"
SELECT
    SUBSTR(a.TABSCHEMA, 1, 12) AS "Schema",
    SUBSTR(a.TABNAME, 1, 32) AS "Table",
    (a.DATA_OBJECT_P_SIZE + a.INDEX_OBJECT_P_SIZE + a.LONG_OBJECT_P_SIZE + a.LOB_OBJECT_P_SIZE + a.XML_OBJECT_P_SIZE) AS "Total Size",
    a.DATA_OBJECT_P_SIZE AS "Data Size",
    a.INDEX_OBJECT_P_SIZE AS "Index Size",
    a.LONG_OBJECT_P_SIZE AS "Long Size",
    a.LOB_OBJECT_P_SIZE AS "Lob Size",
    a.XML_OBJECT_P_SIZE AS "XML Size"
FROM
    SYSIBMADM.ADMINTABINFO a
ORDER BY
    "Total Size" DESC
FETCH FIRST 100 ROWS ONLY;
EOF

# 4. Execute the SQL query from the temporary file
echo ""
echo "--- Top 100 Largest Tables in $DB_NAME ---"
db2 -tvf "$TEMP_SQL_FILE" # Use -tvf for verbose output and file execution

# Optional: If you want *only* the data, you can redirect the output and filter out noise
# db2 -x -f "$TEMP_SQL_FILE" # -x for no headers/footers, -f for file execution

if [ $? -ne 0 ]; then
    echo "ERROR: SQL query execution failed."
    # Keep the temp file for debugging if an error occurs
    echo "Temporary SQL file kept for inspection: $TEMP_SQL_FILE"
    exit 1
fi

# 5. Clean up the temporary SQL file (only if no error)
rm "$TEMP_SQL_FILE"

# 6. Disconnect from DB2
db2 connect reset > /dev/null 2>&1
echo "Disconnected from DB2."

exit 0
