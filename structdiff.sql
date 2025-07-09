/*

The idea of this is to establish if you can modify a table rather than rebuild and
export and import the table data to the new structure.

The purpose of this is to establish the structural differences between two tables.
It assumes they are pretty much similar and that any columns added are put at
the end of the tables. If columns are added in the middle of the table you may want
to modify a copy of the query to remove the COLNO and order only by COLUMNNAME.

Output is ordered so that you can compare differences in the table structures.

For this example, the column ERRORTYPE was changed slightly for the type from
VARACHAR to CHARACTER and the column TENANTNAME was added.


You should verify that the column is the last column of the new table.

COLNO  COLUMNNAME           TYPE                 LENGTH      SCALE  DIFFERENCE_SOURCE
------ -------------------- -------------------- ----------- ------ -----------------
    39 ERRORTYPE            VARCHAR                        8      0 AUDITOLD_TABLE
    39 ERRORTYPE            CHARACTER                      8      0 AUDIT_TABLE
    45 TENANTNAME           VARCHAR                      128      0 AUDIT_TABLE
*/

WITH AUDIT_TABLE AS (
    SELECT COLNO, SUBSTR(COLNAME,1,20) AS ColumnName, SUBSTR(TYPENAME,1,20) AS Type,
           LENGTH, SCALE 
    FROM syscat.columns 
    WHERE TABSCHEMA = 'AUDIT' AND TABNAME = 'AUDIT'
    ORDER BY COLNO
),
AUDITOLD_TABLE AS (
    SELECT COLNO, SUBSTR(COLNAME,1,20) AS ColumnName, SUBSTR(TYPENAME,1,20) AS Type,
           LENGTH, SCALE 
    FROM syscat.columns 
    WHERE TABSCHEMA = 'AUDIT' AND TABNAME = 'AUDITOLD'
    ORDER BY COLNO
)
SELECT
    COALESCE(s1.COLNO, s2.COLNO) AS COLNO,
    COALESCE(s1.ColumnName, s2.ColumnName) AS ColumnName,
    COALESCE(s1.Type, s2.Type) AS Type,
    COALESCE(s1.LENGTH, s2.LENGTH) AS LENGTH,
    COALESCE(s1.SCALE, s2.SCALE) AS SCALE,
    CASE
        WHEN s1.COLNO IS NULL THEN 'AUDITOLD_TABLE'
        WHEN s2.COLNO IS NULL THEN 'AUDIT_TABLE'
        ELSE 'Both'
    END AS Difference_Source
FROM AUDIT_TABLE s1
FULL OUTER JOIN AUDITOLD_TABLE s2
ON s1.COLNO =    s2.COLNO AND
   s1.ColumnName =  s2.ColumnName AND
   s1.Type = s2.Type AND
   s1.LENGTH =   s2.LENGTH AND
   s1.SCALE =    s2.SCALE
WHERE s1.COLNO IS NULL
   OR s2.COLNO IS NULL
   OR s1.ColumnName <> s2.ColumnName
   OR s1.Type <> s2.Type
   OR s1.LENGTH <> s2.LENGTH
   OR s1.SCALE <> s2.SCALE 
order by 1, 2;
