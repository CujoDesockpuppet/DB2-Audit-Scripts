WITH EXECUTE_TABLE AS (
    SELECT COLNO, SUBSTR(COLNAME,1,20) AS ColumnName, SUBSTR(TYPENAME,1,20) AS Type,
           LENGTH, SCALE 
    FROM syscat.columns 
    WHERE TABSCHEMA = 'AUDIT' AND TABNAME = 'EXECUTE'
    ORDER BY COLNO
),
EXECUTE_NEW_TABLE AS (
    SELECT COLNO, SUBSTR(COLNAME,1,20) AS ColumnName, SUBSTR(TYPENAME,1,20) AS Type,
           LENGTH, SCALE 
    FROM syscat.columns 
    WHERE TABSCHEMA = 'DB2CAI' AND TABNAME = 'EXECUTE_NEW'
    ORDER BY COLNO
)
SELECT
    COALESCE(s1.COLNO, s2.COLNO) AS COLNO,
    COALESCE(s1.ColumnName, s2.ColumnName) AS ColumnName,
    COALESCE(s1.Type, s2.Type) AS Type,
    COALESCE(s1.LENGTH, s2.LENGTH) AS LENGTH,
    COALESCE(s1.SCALE, s2.SCALE) AS SCALE,
    CASE
        WHEN s1.COLNO IS NULL THEN 'EXECUTE_NEW_TABLE'
        WHEN s2.COLNO IS NULL THEN 'EXECUTE_TABLE'
        ELSE 'Both'
    END AS Difference_Source
FROM EXECUTE_TABLE s1
FULL OUTER JOIN EXECUTE_NEW_TABLE s2
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
