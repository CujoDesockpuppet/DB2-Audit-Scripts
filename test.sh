#!/bin/bash
# For SCHEMA1
read -p "Enter the FIRST schema name to compare: " raw_SCHEMA1
SCHEMA1=$(echo "$raw_SCHEMA1" | tr 'a-z' 'A-Z')
echo $SCHEMA1
# For SCHEMA2
read -p "Enter the SECOND schema name to compare: " raw_SCHEMA2
SCHEMA2=$(echo "$raw_SCHEMA2" | tr 'a-z' 'A-Z')
echo $SCHEMA2
