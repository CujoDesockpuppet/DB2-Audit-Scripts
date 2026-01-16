#!/bin/bash

TARGET_SCHEMA="AUDIT" # <--- IMPORTANT: Replace with your actual schema name
CUR_SID="$DB2DBDFT"         # <--- IMPORTANT: Replace with your actual database name

echo "Connecting to DB2 database: ${CUR_SID}..."
db2 connect to "$CUR_SID"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to database ${CUR_SID}. Aborting."
    exit 1
fi
echo "Successfully connected to DB2."

# Get all table names for the target schema and store them in an array
echo "Fetching tables for schema: ${TARGET_SCHEMA}..."
# Use mapfile (or readarray) to populate an array, which handles newlines robustly.
# This ensures each line (table name) is a distinct element.
mapfile -t TABLE_ARRAY < <(db2 -x "SELECT TABNAME FROM SYSCAT.TABLES WHERE TABSCHEMA = '${TARGET_SCHEMA}' AND TYPE = 'T' ORDER BY TABNAME" \
    | sed 's/^[ \t]*//;s/[ \t]*$//' | sed '/^$/d')

# Check if the array is empty
if [ ${#TABLE_ARRAY[@]} -eq 0 ]; then
    echo "No tables found in schema ${TARGET_SCHEMA}."
    db2 connect reset
    echo "Disconnected from DB2."
    exit 0
fi

echo "Found tables: ${TABLE_ARRAY[*]}" # Print the list of found tables
echo "--------------------------------------------------------"

for TABLE_NAME in "${TABLE_ARRAY[@]}"; do # Iterate over the array elements
    echo ""
    echo "Table: ${TARGET_SCHEMA}.${TABLE_NAME}"
    echo "--------------------------------------------------------"
    echo "Type  Len  Col Name     C.Len Description" # Custom heading for columns
    echo "----- ---- ------------ ----- ------------------------------" # Separator

    # Query SYSCAT.COLUMNS for column details and remarks
    # Using 'db2 -x' for clean output, then 'awk' for formatting
    db2 -x "SELECT
        T.TYPENAME,
        C.LENGTH,
        C.COLNAME,
        LENGTH(C.COLNAME),
        C.REMARKS
    FROM
        SYSCAT.COLUMNS C
    JOIN
        SYSCAT.DATATYPES T ON C.TYPENAME = T.TYPENAME
    WHERE
        C.TABSCHEMA = '${TARGET_SCHEMA}' AND C.TABNAME = '${TABLE_NAME}'
    ORDER BY
        C.COLNO" \
    | awk '
    {
        # Trim leading/trailing whitespace from each field
        gsub(/^[ \t]+|[ \t]+$/, "", $0);

        # Split into fields by one or more spaces/tabs
        split($0, a, /[ \t]+/);

        # Assign fields to variables for clarity
        type = a[1];
        len = a[2];
        colname = a[3];
        collen = a[4];
        
        # Handle REMARKS (description) - it might contain spaces
        # Reconstruct remarks from 5th field onwards
        remarks = "";
        for (i = 5; i <= NF; i++) {
            remarks = remarks (remarks == "" ? "" : " ") a[i];
        }

        # Truncate values to fit desired column widths
        if (length(type) > 5) type = substr(type, 1, 5);
        if (length(colname) > 12) colname = substr(colname, 1, 12);
        if (length(remarks) > 50) remarks = substr(remarks, 1, 50); # Adjust max length for remarks

        # Print formatted line
        printf "%-5s %-4s %-12s %-5s %-30s\n", type, len, colname, collen, remarks;
    }'

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to retrieve column info for ${TARGET_SCHEMA}.${TABLE_NAME}."
    fi
    echo "--------------------------------------------------------"
done

echo ""
db2 connect reset
echo "Disconnected from DB2."
echo "Finished processing all tables in schema ${TARGET_SCHEMA}."
