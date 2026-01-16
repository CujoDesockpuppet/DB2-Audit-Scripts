-- SQL Analysis - Heavy Logical Reads SQL: SQL_L_READS.SQL
-- Only looks at Bufferpool Data and Index Logical Reads
-- Could be enhanced to include TEMP & XDA Logical Reads if appropriate
-- TRY SORTING BY PCT_IX_L_READS (5) DESC to find heavy IX Access
-- TRY SORTING BY PCT_L_READS (3) DESC to find heavy total L Read Access
-- Results best viewed with command Window 200 characters wide
-- Author: Scott.Hayes@DBIsoftware.com
-- Version: 1.0
-- Last Updated: 2014-03-13
-- Copyright 2014 DBI.  All Rights Reserved.
-- Licensed for use by paid IDUG 2014 Attendees and Authorized DBI Customers Only
--
SELECT CAST (A.NUM_EXECUTIONS AS INTEGER) AS NUMEXECS,
       CAST( (A.POOL_DATA_L_READS + A.POOL_INDEX_L_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_L_READS,
       CAST((((A.POOL_DATA_L_READS + A.POOL_INDEX_L_READS) * 100.0) 
        / (Select (SUM(B.POOL_DATA_L_READS) + SUM(B.POOL_INDEX_L_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_LREADS, 
       CAST( (A.POOL_INDEX_L_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_IX_LREADS,
       CAST((((A.POOL_INDEX_L_READS) * 100.0) 
        / (Select (SUM(B.POOL_INDEX_L_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_IX_LREADS, 
       CAST( (A.POOL_DATA_L_READS + 0.001) / (A.NUM_EXECUTIONS + 0.001)
             AS DECIMAL (13,4)) AS AV_DT_LREADS,
       CAST((((A.POOL_DATA_L_READS) * 100.0) 
        / (Select (SUM(B.POOL_DATA_L_READS) + 0.01)
             FROM SYSIBMADM.SNAPDYN_SQL B 
            WHERE A.DBPARTITIONNUM = B.DBPARTITIONNUM
              )) AS DECIMAL(5,2)) AS PCT_DT_LREADS, 
       SUBSTR(A.STMT_TEXT,1,120) AS HEAVY_L_READ_SQL
FROM SYSIBMADM.SNAPDYN_SQL A
 WHERE A.NUM_EXECUTIONS > 0 
   AND ( (A.POOL_DATA_L_READS > 0) OR (A.POOL_INDEX_L_READS > 0) )
ORDER BY A.DBPARTITIONNUM ASC, 5 DESC, 4 DESC FETCH FIRST 25 ROWS ONLY;

