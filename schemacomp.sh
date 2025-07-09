#!/bin/bash

# --- Configuration ---
# No need to hardcode DB_NAME here anymore, it will come from the SID parameter.

# --- Global Variable for DB2 Instance User ---
DB2_INSTANCE_USER=""

# --- Usage Function ---
usage() {
    echo "Usage: $0 <DB2_SID> [DB_NAME]"
    echo ""
    echo "  <DB2_SID>  : The DB2 System ID (e.g., 'CAI', 'CAP'). This will be used to derive the DB2 instance owner user (db2<SID>)."
    echo "  [DB_NAME]  : Optional. The specific database name to connect to. If not provided, the script will prompt for it."
    echo ""
    echo "Example: $0 CAI"
    exit 1
}

# --- Validate User Function ---
validate_db2_user() {
    local current_user=$(whoami)

    if [ -z "$DB2_INSTANCE_USER" ]; then
        echo "ERROR: DB2_INSTANCE_USER variable is not set. This is an internal script error. Exiting."
        exit 1
    fi

    if [ "$current_user" != "$DB2_INSTANCE_USER" ]; then
        echo "ERROR: This script must be run by the DB2 instance owner user: '$DB2_INSTANCE_USER'"
        echo "Current user is: '$current_user'"
        exit 1
    fi
    echo "User validation successful: Running as '$current_user'."
}

# --- Function to check if a schema exists ---
check_schema_exists() {
    local schema_name="$1"
    local db_name="$2" # Now takes DB name as an argument
    echo "Checking if schema '$schema_name' exists in database '$db_name'..."
    # Using db2 -x to suppress headers/footers, and 2>/dev/null to silence connection messages
    SCHEMA_COUNT=$(db2 -x "SELECT COUNT(*) FROM SYSCAT.SCHEMATA WHERE SCHEMANAME = '$schema_name'" 2>/dev/null)

    if [ -z "$SCHEMA_COUNT" ]; then
        echo "ERROR: Could not query SYSCAT.SCHEMATA for schema '$schema_name'. Ensure you are connected to database '$db_name' and have permissions."
        return 1
    fi

    if [ "$SCHEMA_COUNT" -eq 0 ]; then
        echo "ERROR: Schema '$schema_name' does NOT exist in database '$db_name'."
        return 1 # Indicate failure
    else
        echo "Schema '$schema_name' exists."
        return 0 # Indicate success
    fi
}

# --- Main Script Execution ---

# 1. Parse Input Parameters
if [ -z "$1" ]; then
    echo "ERROR: DB2 SID parameter is required."
    usage
fi

DB2_SID="$1"
DB2_INSTANCE_USER="db2$(echo "$DB2_SID" | tr '[:upper:]' '[:lower:]')" # Convert SID to lowercase for user derivation
DB_NAME_PARAM="$2" # Capture the optional DB_NAME

# 2. Validate the running user
validate_db2_user

# 3. Connect to the database
# If DB_NAME_PARAM is provided, use it. Otherwise, prompt.
if [ -n "$DB_NAME_PARAM" ]; then
    DB_NAME="$DB_NAME_PARAM"
    echo "Attempting to connect to specified database: $DB_NAME"
else
    read -p "Enter the database name to connect to: " DB_NAME
    if [ -z "$DB_NAME" ]; then
        echo "ERROR: Database name cannot be empty. Exiting."
        exit 1
    fi
fi

db2 connect to "$DB_NAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to database '$DB_NAME'. Please check DB name, DB2 instance, and user permissions."
    # Optionally, provide more details about the connection error
    # db2 connect to "$DB_NAME" # Uncomment this to see the raw DB2 error message
    exit 1
fi
echo "Successfully connected to $DB_NAME."

# 4. Prompt for Schema 1 with validation
while true; do
            read -p "Enter the FIRST schema name to compare: " raw_SCHEMA1
            SCHEMA1=$(echo "$raw_SCHEMA1" | tr 'a-z' 'A-Z')
    #read -p "Enter the FIRST schema name to compare: " SCHEMA1
    if [ -z "$SCHEMA1" ]; then
        echo "Schema name cannot be empty. Please try again."
    elif check_schema_exists "$SCHEMA1" "$DB_NAME"; then
        break # Exit loop if schema exists
    fi
done

# 5. Prompt for Schema 2 with validation
while true; do
            read -p "Enter the FIRST schema name to compare: " raw_SCHEMA2
           SCHEMA2=$(echo "$raw_SCHEMA2" | tr 'a-z' 'A-Z')   
#read -p "Enter the SECOND schema name to compare: " SCHEMA2
    if [ -z "$SCHEMA2" ]; then
        echo "Schema name cannot be empty. Please try again."
    elif [ "$SCHEMA1" = "$SCHEMA2" ]; then
        echo "The second schema name cannot be the same as the first. Please enter a different schema."
    elif check_schema_exists "$SCHEMA2" "$DB_NAME"; then
        break # Exit loop if schema exists
    fi
done

echo "Starting schema comparison between '$SCHEMA1' and '$SCHEMA2' in database '$DB_NAME'."

# 6. Dynamically generate the SQL query with the user-provided schemas
TEMP_SQL_FILE="/tmp/schema_compare_temp_$(date +%s%N).sql" # Unique temp file

cat <<EOF > "$TEMP_SQL_FILE"
-- Step 1: Find common table names first (tables present in both schemas)
WITH CommonTables AS (
    SELECT T.TABNAME
    FROM SYSCAT.TABLES AS T
    WHERE T.TABSCHEMA = '$SCHEMA1'
    INTERSECT
    SELECT U.TABNAME
    FROM SYSCAT.TABLES AS U
    WHERE U.TABSCHEMA = '$SCHEMA2'
),
-- Step 2: Get full column details for common tables from Schema 1
Schema1Columns AS (
    SELECT
        C.TABNAME, C.COLNAME, C.COLNO, C.TYPENAME, C.LENGTH, C.SCALE, C.NULLS, C.DEFAULT
    FROM SYSCAT.COLUMNS AS C
    INNER JOIN CommonTables CT ON C.TABNAME = CT.TABNAME
    WHERE C.TABSCHEMA = '$SCHEMA1'
),
-- Step 3: Get full column details for common tables from Schema 2
Schema2Columns AS (
    SELECT
        C.TABNAME, C.COLNAME, C.COLNO, C.TYPENAME, C.LENGTH, C.SCALE, C.NULLS, C.DEFAULT
    FROM SYSCAT.COLUMNS AS C
    INNER JOIN CommonTables CT ON C.TABNAME = CT.TABNAME
    WHERE C.TABSCHEMA = '$SCHEMA2'
)
-- Report 1: Columns present in Schema 1's version of the table but NOT in Schema 2's (or with different properties)
SELECT
    '${SCHEMA1}_ONLY_COLUMN_OR_DIFFERENT_PROPERTIES' AS DifferenceType,
    AC.TABNAME AS TableName,
    AC.COLNAME AS ColumnName,
    AC.COLNO AS Schema1ColNo,
    AC.TYPENAME AS Schema1TypeName,
    AC.LENGTH AS Schema1Length,
    AC.SCALE AS Schema1Scale,
    AC.NULLS AS Schema1Nulls,
    AC.DEFAULT AS Schema1Default,
    CAST(NULL AS SMALLINT) AS Schema2ColNo,
    CAST(NULL AS VARCHAR(128)) AS Schema2TypeName,
    CAST(NULL AS INTEGER) AS Schema2Length,
    CAST(NULL AS SMALLINT) AS Schema2Scale,
    CAST(NULL AS CHAR(1)) AS Schema2Nulls,
    CAST(NULL AS VARCHAR(4000)) AS Schema2Default
FROM Schema1Columns AC
LEFT JOIN Schema2Columns AOC
    ON AC.TABNAME = AOC.TABNAME
    AND AC.COLNAME = AOC.COLNAME
    AND AC.COLNO = AOC.COLNO
    AND AC.TYPENAME = AOC.TYPENAME
    AND AC.LENGTH = AOC.LENGTH
    AND AC.SCALE = AOC.SCALE
    AND AC.NULLS = AOC.NULLS
    AND AC.DEFAULT = AOC.DEFAULT
WHERE AOC.TABNAME IS NULL

UNION ALL

-- Report 2: Columns present in Schema 2's version of the table but NOT in Schema 1's (or with different properties)
SELECT
    '${SCHEMA2}_ONLY_COLUMN_OR_DIFFERENT_PROPERTIES' AS DifferenceType,
    AOC.TABNAME AS TableName,
    AOC.COLNAME AS ColumnName,
    CAST(NULL AS SMALLINT) AS Schema1ColNo,
    CAST(NULL AS VARCHAR(128)) AS Schema1TypeName,
    CAST(NULL AS INTEGER) AS Schema1Length,
    CAST(NULL AS SMALLINT) AS Schema1Scale,
    CAST(NULL AS CHAR(1)) AS Schema1Nulls,
    CAST(NULL AS VARCHAR(4000)) AS Schema1Default,
    AOC.COLNO AS Schema2ColNo,
    AOC.TYPENAME AS Schema2TypeName,
    AOC.LENGTH AS Schema2Length,
    AOC.SCALE AS Schema2Scale,
    AOC.NULLS AS Schema2Nulls,
    AOC.DEFAULT AS Schema2Default
FROM Schema2Columns AOC
LEFT JOIN Schema1Columns AC
    ON AOC.TABNAME = AC.TABNAME
    AND AOC.COLNAME = AC.COLNAME
    AND AOC.COLNO = AC.COLNO
    AND AOC.TYPENAME = AC.TYPENAME
    AND AOC.LENGTH = AC.LENGTH
    AND AOC.SCALE = AC.SCALE
    AND AOC.NULLS = AC.NULLS
    AND AOC.DEFAULT = AC.DEFAULT
WHERE AC.TABNAME IS NULL

UNION ALL

-- Report 3: Columns with the SAME Name and Table, but DIFFERENT attribute values
SELECT
    'DIFFERENT_ATTRIBUTE_VALUES' AS DifferenceType,
    AC.TABNAME AS TableName,
    AC.COLNAME AS ColumnName,
    AC.COLNO AS Schema1ColNo,
    AC.TYPENAME AS Schema1TypeName,
    AC.LENGTH AS Schema1Length,
    AC.SCALE AS Schema1Scale,
    AC.NULLS AS Schema1Nulls,
    AC.DEFAULT AS Schema1Default,
    AOC.COLNO AS Schema2ColNo,
    AOC.TYPENAME AS Schema2TypeName,
    AOC.LENGTH AS Schema2Length,
    AOC.SCALE AS Schema2Scale,
    AOC.NULLS AS Schema2Nulls,
    AOC.DEFAULT AS Schema2Default
FROM Schema1Columns AC
INNER JOIN Schema2Columns AOC
    ON AC.TABNAME = AOC.TABNAME
    AND AC.COLNAME = AOC.COLNAME
WHERE
    AC.COLNO <> AOC.COLNO OR
    AC.TYPENAME <> AOC.TYPENAME OR
    AC.LENGTH <> AOC.LENGTH OR
    AC.SCALE <> AOC.SCALE OR
    AC.NULLS <> AOC.NULLS OR
    (AC.DEFAULT IS DISTINCT FROM AOC.DEFAULT);
EOF

# 7. Execute the dynamically generated SQL
db2 -tvf "$TEMP_SQL_FILE"

# 8. Clean up the temporary SQL file
rm "$TEMP_SQL_FILE"

# 9. Disconnect from DB2
db2 connect reset > /dev/null 2>&1
echo "Comparison complete and disconnected from DB2."
