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
-- Removed redundant join to SYSCAT.tables
ORDER BY
    "Total Size" DESC -- Use alias for clarity, or the column number 3
FETCH FIRST 100 ROWS ONLY;
